import from "node:os" { default as os }
import from "node:path" { default as path }
import from "node:process" { default as process }
import from "node:fs" {
    existsSync,
    lstatSync,
    mkdirSync,
    readFileSync,
    realpathSync,
    rmSync,
    statSync,
    writeFileSync,
}

type SkillScope = any;

glob SKILL_SCOPES: list[str] = ["global", "project"];

glob:priv LOCK_WAIT_MS: int = 60000,
          LOCK_STALE_MS: int = 600000;

def:priv supportedAgents -> any {
    return need("skills").getSupportedAgents();
}

def supportsGlobalSkills(toolId: str) -> bool {
    return installerAgent(toolId)["globalSkillsDir"] is not JsNull;
}

def isHomeFolder(projectPath: str) -> bool {
    def real(target: str) -> str {
        try {
            return realpathSync.native(target);
        } except Exception {
            return path.resolve(target);
        }
    }
    return real(projectPath) == real(os.homedir());
}

def projectHasOwnSkills(projectPath: str) -> bool {
    if isHomeFolder(projectPath) {
        return False;
    }
    for id in getConfiguredTools(projectPath) {
        tool = AI_TOOLS.find(lambda (t: any) -> bool { t.value == id });
        if not at(tool, "globalSkillsDir") {
            return True;
        }
    }
    return False;
}

def:priv globalDirectories -> dict[str, str] {
    dirs: dict[str, str] = {"universal": path.join(os.homedir(), ".agents", "skills")};
    for agent in supportedAgents() {
        if (not agent.universal or agent.id in ["antigravity", "antigravity-cli"])
            and agent["globalSkillsDir"]
        {
            dirs[agent.id] = agent.globalSkillsDir;
        }
    }
    return dirs;
}

async def readGlobalSkills -> any {
    agents: list[str] = [];
    skills: list[str] = [];
    for (agent, dir) in globalDirectories().items() {
        names = [
            name
            for name in OPENSPEC_SKILL_NAMES
            if existsSync(path.join(dir, name, "SKILL.md"))
        ];
        if names {
            agents.append(agent);
        }
        skills.extend(names);
    }
    return rec(skills=unique(skills), agents=agents);
}

def:priv isCurrent(dir: str, name: str, expected: any) -> bool {
    for (file, text) in expected.get(name).entries() {
        try {
            if readFileSync(path.join(dir, name, file), "utf8").replaceAll("\r\n", "\n") != text {
                return False;
            }
        } except Exception {
            return False;
        }
    }
    return True;
}

async def installGlobalSkills(input: any) -> any {
    async def refresh -> any {
        before = await readGlobalSkills();
        agents = unique(
            ["universal", *before.agents] + [
                installerAgent(id).id
                for id in at(input, "toolIds") or []
            ],
        );
        expected = expectedSkillFiles(input.version, withRouter(input.workflows));
        skills = globalThis.Array.from(expected.keys());
        removedSkills = [name for name in before.skills if not expected.has(name)];
        dirs = globalDirectories();
        current = all([
            isCurrent(dirs.get(agent, dirs["universal"]), name, expected)
            for agent in agents
            for name in skills
        ]);
        unchanged = current and not truthy(input["force"]) and not removedSkills;
        if not unchanged and not truthy(input["dryRun"]) {
            targets = rec(scope="global", agents=agents);
            failures = await installReleaseSkills(targets, skills, input.version);
            if failures.size {
                raise new(
                    globalThis.Error,
                    "\n".join([e.message for e in globalThis.Array.from(failures.values())]),
                );
            }
            universal = [a.id for a in supportedAgents() if a.universal and a["globalSkillsDir"]];
            await removeManagedSkills(
                merge(targets, rec(agents=unique(agents + universal))), removedSkills
            );
            left = unique([
                spot
                for agent in agents
                for spot in [
                    path.join(dirs.get(agent, dirs["universal"]), name)
                    for name in removedSkills
                ]
                if not missing(lstatSync(spot, rec(throwIfNoEntry=False)))
            ]);
            if left {
                one = len(left) == 1;
                raise new(
                    globalThis.Error,
                    f"Could not remove {', '.join(left)}. Remove {'it' if one else 'them'} by hand, then run openspec update again.",
                );
            }
        }
        return rec(skills=skills, removedSkills=removedSkills, unchanged=unchanged);
    }
    return await (refresh() if truthy(input["dryRun"]) else withGlobalSkillsLock(refresh));
}

def:priv isRunning(pid: any) -> bool {
    try {
        process.kill(pid, 0);
        return True;
    } except Exception as e {
        return js_error(e)["code"] == "EPERM";
    }
}

async def:priv withGlobalSkillsLock(work: any) -> any {
    lock = path.join(getGlobalDataDir(), "global-skills.lock");
    owner = path.join(lock, "pid");
    now = globalThis.Date.now;
    deadline = now() + LOCK_WAIT_MS;
    held = False;
    while True {
        try {
            mkdirSync(path.dirname(lock), rec(recursive=True));
            mkdirSync(lock);
            writeFileSync(owner, globalThis.String(process.pid));
            held = True;
            break;
        } except Exception as e {
            if js_error(e)["code"] != "EEXIST" {
                break;
            }
        }
        try {
            age = now() - statSync(lock).mtimeMs;
        } except Exception {
            break;
        }
        pid: any = globalThis.Number.NaN;
        try {
            pid = globalThis.Number(readFileSync(owner, "utf8").trim());
        } except Exception {}
        if (
            not isRunning(pid)
                if globalThis.Number.isInteger(pid) and pid > 0
                else age > LOCK_STALE_MS
        ) {
            rmSync(lock, rec(recursive=True, force=True));
            continue;
        }
        if now() > deadline {
            raise new(
                globalThis.Error,
                f"Another openspec run is still changing the skills for this machine. Run this again when it has finished. If no other run is going, delete {lock}",
            );
        }
        await new(
            globalThis.Promise, lambda (resolve: any) -> any { globalThis.setTimeout(resolve, 200) }
        );
    }
    try {
        return await work();
    } finally {
        if held {
            rmSync(lock, rec(recursive=True, force=True));
        }
    }
}

def describeSkillsError(error: any) -> str {
    if not globalThis.Error.prototype.isPrototypeOf(error) {
        return globalThis.String(error);
    }
    fix: any = error["fix"];
    return f"{error.message} {fix}" if kind(fix) == "string" and len(fix) > 0 else error.message;
}

def describeRemovedSkills(names: any, done: bool = True) -> any {
    if len(names) == 0 {
        return None;
    }
    one = len(names) == 1;
    return f"{'Removed' if done else 'Update will remove'} {len(names)} skill{'' if one else 's'} your workflow profile doesn't include: {', '.join(names)}. To keep {'it' if one else 'them'}, add {'its workflow' if one else 'their workflows'} with: openspec config profile";
}
