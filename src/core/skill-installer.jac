import from "node:buffer" { Buffer }
import from "node:crypto" { createHash }
import from "node:fs" { promises as fs }
import from "node:os" { default as os }
import from "node:path" { default as path }
import from "node:process" { default as process }

type SkillScope = any;

glob:priv toMap: any = new(
    globalThis.Function,
    "f",
    "return (...a) => { const r = f(...a); return r instanceof Promise ? r.then((p) => new Map(p)) : new Map(r); }",
);

def:priv skillFilePairs(version: str, workflows: any = None) -> any {
    return [
        [
            e.dirName,
            [
                [file, stripVolatileFrontmatter(text)]
                for (file, text) in generateSkillFiles(
                    e.template, version, transformToSharedSkillReferences
                ).entries()
            ],
        ]
        for e in getSkillTemplates(workflows)
    ];
}

glob expectedSkillFiles: any = new(
    globalThis.Function,
    "f",
    "const all = new Map(); const build = (v, w) => new Map(f(v, w).map(([k, x]) => [k, new Map(x)])); return (v, w) => w ? build(v, w) : all.get(v) ?? all.set(v, build(v)).get(v);",
)(skillFilePairs);

glob expectedSkillContents: any = toMap(
    lambda (version: str, workflows: any = None) -> any {
        return [
            [name, files.get("SKILL.md")]
            for (name, files) in expectedSkillFiles(version, workflows).entries()
        ];
    },
);

def projectSkillText(toolId: str, shared: any) -> any {
    header: any = matchOf(shared, "^---\\n([\\s\\S]*?)\\n---\\n\\n?")
        if toolId == "eve"
        else JsNull;
    if header is JsNull {
        return shared;
    }
    yaml = need("yaml");
    fields: any = yaml.parse(header[1]);
    globalThis.Reflect.deleteProperty(fields, "allowed-tools");
    return f"---\n{yaml.stringify(fields)}---\n{shared.slice(header[0].length)}";
}

def:priv gitObject(type_: str, body: any) -> any {
    return createHash("sha1").update(f"{type_} {body.length}\x00").update(body).digest();
}

def:priv tree(entries: any) -> any {
    blobs: dict[str, any] = {};
    dirs: dict[str, list[any]] = {};
    for (file, text) in entries {
        parts: any = file.split("/");
        if len(parts) > 1 {
            dirs.setdefault(parts[0], []).append(["/".join(parts[1:]), text]);
        } else {
            blobs[file] = gitObject("blob", Buffer.from(text));
        }
    }
    rows: list[any] = [
        [name, Buffer.from(f"100644 {name}\x00"), sha]
        for (name, sha) in blobs.items()
    ];
    rows.extend([
        [f"{name}/", Buffer.from(f"40000 {name}\x00"), tree(sub)]
        for (name, sub) in dirs.items()
    ]);
    return gitObject(
        "tree",
        Buffer.concat([
            b
            for r in sorted(rows, key=lambda (r: any) -> any { r[0] })
            for b in r[1:]
        ]),
    );
}

async def:priv recordGlobalSkills(names: any, expected: any, version: str) {
    if not names {
        return;
    }
    stateHome: any = process.env["XDG_STATE_HOME"];
    lockPath = path.join(stateHome, "skills", ".skill-lock.json")
        if stateHome
        else path.join(os.homedir(), ".agents", ".skill-lock.json");
    lock: any = rec(version=3, skills=rec(), dismissed=rec());
    try {
        saved: any = globalThis.JSON.parse(await fs.readFile(lockPath, "utf8"));
        if kind(saved["version"]) == "number"
            and saved["version"] >= 3
            and truthy(saved["skills"])
        {
            lock = saved;
        }
    } except Exception {}
    now = new(globalThis.Date).toISOString();
    for name in names {
        installedAt: any = at(lock.skills[name], "installedAt");
        lock.skills[name] = rec(
            source="Fission-AI/OpenSpec",
            sourceType="github",
            sourceUrl="https://github.com/Fission-AI/OpenSpec.git",
            ref=f"v{version}",
            skillPath=f"skills/{name}/SKILL.md",
            skillFolderHash=tree(expected.get(name).entries()).toString("hex"),
            installedAt=now if missing(installedAt) else installedAt,
            updatedAt=now,
        );
    }
    await fs.mkdir(path.dirname(lockPath), rec(recursive=True));
    await fs.writeFile(lockPath, globalThis.JSON.stringify(lock, None, 2));
}

async def:priv installPairs(targets: any, names: any, version: str) -> any {
    if not names {
        return [];
    }
    failures: any = new(globalThis.Map);
    expected = expectedSkillFiles(version);
    source = path.resolve(await fs.mkdtemp(path.join(os.tmpdir(), "openspec-skills-")));
    result: any = None;
    try {
        for name in names {
            for (file, text) in expected.get(name).entries() {
                target = path.join(source, "skills", name, file);
                await fs.mkdir(path.dirname(target), rec(recursive=True));
                await fs.writeFile(target, text);
            }
        }
        result = await (await load("skills")).installSkills(
            source,
            merge(
                targets,
                rec(
                    skills=names,
                    telemetry=False,
                    lockfile=False,
                    mode="copy"
                        if targets.scope == "project" and process.platform == "win32"
                        else "auto",
                ),
            ),
        );
    } finally {
        await fs.rm(source, rec(recursive=True, force=True)).catch(lambda (e: any) -> any { None });
    }
    if targets.scope == "global" {
        await recordGlobalSkills(
            globalThis.Array.from(new(globalThis.Set, [e.skill for e in result.installed])),
            expected,
            version,
        );
    }
    async def matches(dir: str, name: str) -> bool {
        for (file, text) in (expected.get(name) ?? new(globalThis.Map)).entries() {
            found: any = await fs.readFile(path.join(dir, file), "utf8").catch(
                lambda (e: any) -> any { None }
            );
            if missing(found) or found.replaceAll("\r\n", "\n") != text {
                return False;
            }
        }
        return True;
    }
    for failure in result.failed {
        failures.set(failure.agent, new(globalThis.Error, failure.message));
    }
    for skipped in result.skipped {
        failures.set(
            skipped.agent,
            new(globalThis.Error, f"{skipped.agent} skipped {skipped.skill}: {skipped.reason}"),
        );
    }
    for agent in targets.agents {
        if failures.has(agent) {
            continue;
        }
        for name in names {
            hits = [t for t in result.installed if t.agent == agent and t.skill == name];
            if hits and (targets.scope == "project" or await matches(hits[0].path, name)) {
                continue;
            }
            failures.set(agent, new(globalThis.Error, f"{agent} did not install {name}"));
            break;
        }
    }
    return list(failures.entries());
}

glob installReleaseSkills: any = toMap(installPairs);

async def removeManagedSkills(targets: any, names: any) {
    if not names {
        return;
    }
    result = await (await load("skills")).removeSkills(
        names, merge(targets, rec(telemetry=False, lockfile=targets.scope == "global"))
    );
    if result.failed {
        raise new(globalThis.Error, "\n".join([f.message for f in result.failed]));
    }
}
