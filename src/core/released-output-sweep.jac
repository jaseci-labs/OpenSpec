import from "node:path" { default as path }
import from "node:fs" { promises as fs }

glob:priv SHARED_TARGET_MARKER: str = ".openspec-target";

def:priv toPosix(p: str) -> str {
    return "/".join(p.split(path.sep)).replace("\\", "/");
}

def:priv topFolder(rel: str) -> str {
    return rel.split("/")[0];
}

def:priv findTool(toolId: str) -> any {
    return AI_TOOLS.find(lambda (t: any) -> bool { t.value == toolId });
}

def:priv skillFiles(dirName: str) -> list[any] {
    files: any = expectedSkillFiles("current").get(dirName);
    return ["SKILL.md"] if missing(files) else globalThis.Array.from(files.keys());
}

def:priv toolSpecificPathsForTool(toolId: str) -> list[str] {
    tool = findTool(toolId);
    if not tool {
        return [];
    }
    paths: list[str] = [];
    if SKILL_LINKED_TOOL_IDS.has(tool.value) {
        ownSkillsRoot = installerAgent(tool.value).projectSkillsDir;
        for workflow in SKILL_WORKFLOWS {
            skillDir = f"{ownSkillsRoot}/{WORKFLOW_TO_SKILL_DIR[workflow]}";
            paths.append(skillDir);
            paths.extend([
                f"{skillDir}/{file}"
                for file in skillFiles(WORKFLOW_TO_SKILL_DIR[workflow])
            ]);
        }
    }
    adapter = CommandAdapterRegistry.get(tool.value);
    if adapter {
        for commandId in COMMAND_IDS {
            file = adapter.getFilePath(commandId);
            if not path.isAbsolute(file) {
                paths.append(toPosix(file));
            }
        }
    }
    return paths;
}

def:priv currentPathsForTool(tool: any) -> list[str] {
    paths = toolSpecificPathsForTool(tool.value);
    if usesSharedSkills(tool) {
        for workflow in SKILL_WORKFLOWS {
            dirName = WORKFLOW_TO_SKILL_DIR[workflow];
            paths.extend([
                f"{SHARED_SKILLS_ROOT}/skills/{dirName}/{file}"
                for file in skillFiles(dirName)
            ]);
        }
    }
    return paths;
}

def currentGeneratablePaths -> any {
    paths: list[str] = [p for tool in AI_TOOLS for p in currentPathsForTool(tool)];
    paths.append(f"{SHARED_SKILLS_ROOT}/skills/{SHARED_TARGET_MARKER}");
    paths.extend([
        f"{tool.skillsDir}/skills/{SHARED_TARGET_MARKER}"
        for tool in AI_TOOLS
        if tool["skillsDir"] and not tool["globalSkillsDir"] and not usesSharedSkills(tool)
    ]);
    return new(globalThis.Set, paths);
}

def:priv formerRoots(toolId: str) -> list[any] {
    roots: list[any] = [legacy.root for legacy in LEGACY_TOOL_ROOTS[toolId] ?? []];
    roots.extend(at(findTool(toolId), "legacySkillsDirs") ?? []);
    return unique(roots);
}

def:priv folderOwners -> dict[str, list[str]] {
    owners: dict[str, list[str]] = {};
    def add(folder: any, toolId: str) {
        if folder {
            ids = owners.setdefault(folder, []);
            if toolId not in ids {
                ids.append(toolId);
            }
        }
    }
    for tool in AI_TOOLS {
        add(tool["skillsDir"], tool.value);
        for r in formerRoots(tool.value) {
            add(r, tool.value);
        }
        for p in toolSpecificPathsForTool(tool.value) {
            add(topFolder(p), tool.value);
        }
    }
    return owners;
}

def:priv migrationManagedPaths(toolId: str, folder: str) -> list[tuple[str, str]] {
    tool = findTool(toolId);
    if not at(tool, "skillsDir") {
        return [];
    }
    paths: list[tuple[str, str]] = [
        (f"{folder}/skills/{dir}/SKILL.md", f"{tool.skillsDir}/skills/{dir}/SKILL.md")
        for dir in globalThis.Object.values(WORKFLOW_TO_SKILL_DIR)
    ];
    adapter = CommandAdapterRegistry.get(toolId);
    if adapter {
        for commandId in COMMAND_IDS {
            current = adapter.getFilePath(commandId);
            former = legacyCommandPath(current, tool.skillsDir, folder);
            if former {
                paths.append((toPosix(former), toPosix(current)));
            }
        }
    }
    return paths;
}

def:priv replacedBeforeCleanup(toolId: str, folder: str) -> bool {
    for legacy in LEGACY_TOOL_ROOTS[toolId] ?? [] {
        if legacy.root == folder and legacy["timing"] == "after-generation" {
            return True;
        }
    }
    return False;
}

async def findStaleReleasedFiles(projectPath: str, view: any = None) -> list[str] {
    view = view ?? DISK_VIEW;
    current = currentGeneratablePaths();
    owners = folderOwners();
    def exists(rel: str) -> bool {
        return view.exists(path.join(projectPath, *rel.split("/")));
    }
    hasReplacement: dict[str, bool] = {};
    def replaced(toolId: str) -> bool {
        if toolId not in hasReplacement {
            hasReplacement[toolId] = len([p for p in toolSpecificPathsForTool(toolId) if exists(p)])
                > 0
                or isToolListed(projectPath, toolId, view);
        }
        return hasReplacement[toolId];
    }
    def migrationPending(folder: str) -> bool {
        for tool in AI_TOOLS {
            if folder not in formerRoots(tool.value) {
                continue;
            }
            needsReplacement = replacedBeforeCleanup(tool.value, folder);
            for (former, replacement) in migrationManagedPaths(tool.value, folder) {
                if exists(former) and (not needsReplacement or exists(replacement)) {
                    return True;
                }
            }
        }
        return False;
    }
    top = FileSystemUtils.canonicalizeExistingPath(projectPath);
    stale: list[str] = [];
    for rel in RELEASED_GENERATED_PATHS {
        if current.has(rel) {
            continue;
        }
        ids = owners.get(topFolder(rel), []);
        if not ids
            or len([id for id in ids if not replaced(id)]) > 0
            or migrationPending(topFolder(rel))
        {
            continue;
        }
        file = path.join(projectPath, *rel.split("/"));
        literal = path.join(top, *rel.split("/"));
        try {
            if view.exists(file)
                and (await fs.lstat(literal)).isFile()
                and FileSystemUtils.canonicalizeExistingPath(literal) == literal
                and isReleasedGeneratedContent(view.read(file))
            {
                stale.append(rel);
            }
        } except Exception {}
    }
    return stale;
}

async def pruneEmptyParents(projectPath: str, removed: any) {
    top = FileSystemUtils.canonicalizeExistingPath(projectPath);
    for rel in removed {
        dir = path.dirname(path.join(top, *rel.split("/")));
        while dir != top and dir.startswith(top + path.sep) {
            try {
                if (await fs.lstat(dir)).isSymbolicLink() {
                    break;
                }
                await fs.rmdir(dir);
            } except Exception {
                break;
            }
            dir = path.dirname(dir);
        }
    }
}
