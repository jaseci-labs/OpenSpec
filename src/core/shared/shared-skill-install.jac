import from "node:path" { default as path }
import from "node:fs" { realpathSync }
import from "node:process" { default as process }

type SharedSkillInstallResult = any;

glob:priv run: any = new(globalThis.Function, "o", "k", "a", "return Promise.resolve(o[k](...a))");

def:priv readSkill(dir: str, name: str, view: any, forTool: any = None) -> any {
    try {
        text = normalizeGeneratedFile(view.read(path.join(dir, name, "SKILL.md")));
        return projectSkillText(forTool, text) if forTool else text;
    } except Exception {
        return None;
    }
}

def:priv referencesDiffer(dir: str, name: str, files: any, view: any) -> bool {
    for (file, text) in files.entries() {
        if file == "SKILL.md" {
            continue;
        }
        try {
            if normalizeGeneratedFile(view.read(path.join(dir, name, file))) != text {
                return True;
            }
        } except Exception {
            return True;
        }
    }
    return False;
}

def:priv present(dir: str, view: any) -> bool {
    return view.exists(dir) or linkOf(view, dir) is not None;
}

def ownSkillFolderNeedsWork(project: str, tool: any, wanted: any, view: any) -> bool {
    shared = resolveSharedSkillsDir(project);
    target = resolveSkillLinkDir(project, tool);
    former = resolveFormerOwnSkillsDir(project, tool);
    for name in OPENSPEC_SKILL_NAMES {
        if target and wanted.has(name) {
            content = readSkill(target, name, view);
            if content is None or content != readSkill(shared, name, view, tool.value) {
                return True;
            }
        } elif former
            and present(path.join(former, name), view)
            and not (
                truthy(linkOf(view, path.join(former, name))) and not target and wanted.has(name)
            )
        {
            return True;
        }
    }
    return False;
}

async def:priv install(input: any) -> any {
    (projectPath, ops, view) = (input.projectPath, input.ops, input.view);
    tools = [t for t in input.tools if usesSharedSkills(t)];
    failures: dict[str, any] = {};
    def done(written: int, removed: int) -> any {
        return rec(
            writtenSkillCount=written,
            removedSkillCount=removed,
            toolFailures=[[k, v] for (k, v) in failures.items()],
        );
    }
    if not tools {
        return done(0, 0);
    }
    shared = resolveSharedSkillsDir(projectPath);
    FileSystemUtils.assertPathWithin(projectPath, shared);
    files = expectedSkillFiles(
        input.version, unique([w for t in tools for w in input.workflowsFor(t.value)])
    );
    contents: dict[str, any] = {name: skill.get("SKILL.md") for (name, skill) in files.entries()};
    agents: list[str] = ["universal"];
    targets: dict[str, str] = {shared: "openspec"};
    legacy: list[str] = [];
    sharedPath = FileSystemUtils.canonicalizeExistingPath(shared);
    def sharesFolder(dir: str) -> bool {
        return path.relative(sharedPath, FileSystemUtils.canonicalizeExistingPath(dir)) == "";
    }
    for tool in tools {
        target = resolveSkillLinkDir(projectPath, tool);
        try {
            if target {
                FileSystemUtils.assertPathWithin(projectPath, target);
            }
            if not target or not sharesFolder(target) {
                if target {
                    targets[target] = tool.value;
                }
                agents.append(installerAgent(tool.value).id);
            }
            oldFolders: list[any] = [resolveFormerOwnSkillsDir(projectPath, tool)];
            if not contents {
                oldFolders.extend([
                    path.join(projectPath, r, "skills")
                    for r in tool["legacySkillsDirs"] or []
                ]);
            }
            for old in oldFolders {
                if not old or old == target or old == shared {
                    continue;
                }
                try {
                    FileSystemUtils.assertPathWithin(projectPath, old);
                    if not truthy(linkOf(view, old))
                        and not sharesFolder(old)
                        and old not in legacy
                    {
                        legacy.append(old);
                    }
                } except Exception {}
            }
        } except Exception as e {
            failures[tool.value] = js_error(e);
        }
    }
    agents = unique(agents);
    toInstall: list[str] = [];
    toRemove: list[str] = [];
    for (dir, tool) in targets.items() {
        for name in OPENSPEC_SKILL_NAMES {
            spot = path.join(dir, name);
            source = contents.get(name);
            if source is not None {
                if (
                    readSkill(dir, name, view) != projectSkillText(tool, source)
                    or referencesDiffer(dir, name, files.get(name), view)
                )
                    and name not in toInstall
                {
                    toInstall.append(name);
                }
            } elif present(spot, view) {
                if name not in toRemove {
                    toRemove.append(name);
                }
                if not input.writesToDisk {
                    await run(ops, "removeDirectory", [spot, tool]);
                }
            }
        }
    }
    if not input.writesToDisk {
        for name in toInstall {
            for (dir, tool) in targets.items() {
                spot = path.join(dir, name);
                if dir == shared or tool == "eve" or process.platform == "win32" {
                    if present(spot, view) {
                        await run(ops, "removeDirectory", [spot, tool]);
                    }
                    for (file, text) in files.get(name).entries() {
                        await run(
                            ops,
                            "writeFile",
                            [
                                path.join(spot, file),
                                projectSkillText(tool, text) if file == "SKILL.md" else text,
                                tool,
                            ],
                        );
                    }
                } else {
                    await run(ops, "linkSkill", [spot, path.join(shared, name), tool]);
                }
            }
        }
    } else {
        options = rec(scope="project", cwd=realpathSync(projectPath), agents=agents);
        installed = await installReleaseSkills(options, toInstall, input.version);
        for tool in tools {
            failure = installed.get(installerAgent(tool.value).id) ?? installed.get("universal");
            if not missing(failure) {
                failures[tool.value] = failure;
            }
        }
        if installed.size {
            return done(0, 0);
        }
        await removeManagedSkills(
            merge(
                options,
                rec(
                    agents=unique(
                        agents + [a.id for a in need("skills").getSupportedAgents() if a.universal]
                    ),
                ),
            ),
            toRemove,
        );
        for dir in targets.keys() {
            for name in toRemove {
                if present(path.join(dir, name), view) {
                    await run(ops, "removeDirectory", [path.join(dir, name), "openspec"]);
                }
            }
        }
    }
    for dir in legacy {
        for name in OPENSPEC_SKILL_NAMES {
            spot = path.join(dir, name);
            if present(spot, view) and not (name in contents and truthy(linkOf(view, spot))) {
                await run(ops, "removeDirectory", [spot, "openspec"]);
            }
        }
    }
    marker = skillToolListPath(projectPath);
    if contents {
        owned = [t.value for t in tools if resolveSkillLinkDir(projectPath, t)];
        previousOwn = readListedToolsWithOwnFiles(projectPath, view);
        for tool in tools {
            if tool.value in owned or not previousOwn.has(tool.value) {
                continue;
            }
            former = resolveFormerOwnSkillsDir(projectPath, tool);
            if former
                and len([n for n in contents.keys() if truthy(linkOf(view, path.join(former, n)))])
                    > 0
            {
                owned.append(tool.value);
            }
        }
        listText = formatSkillToolList([t.value for t in tools], new(globalThis.Set, owned));
        if not view.exists(marker) or view.read(marker) != listText {
            await run(ops, "writeFile", [marker, listText, "openspec"]);
        }
    } elif view.exists(marker) {
        await run(ops, "removeFile", [marker, "openspec"]);
    }
    if input.writesToDisk {
        await pruneEmptyParents(
            projectPath,
            [
                path.relative(projectPath, path.join(dir, ".removed"))
                for dir in unique(list(targets.keys()) + legacy)
            ],
        );
    }
    return done(len(contents), len(toRemove));
}

glob installSharedSkills: any = new(
    globalThis.Function,
    "f",
    "return async (input) => { const r = await f(input); return { ...r, toolFailures: new Map(r.toolFailures) }; }",
)(install);
