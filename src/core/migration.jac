import from "node:path" { default as path }
import from "node:fs" {
    existsSync,
    mkdirSync,
    readFileSync,
    readdirSync,
    realpathSync,
    renameSync,
    rmSync,
    rmdirSync,
}

type LegacyToolRoot = any;
type LegacyToolMigration = any;
type LegacyMigrationFileOp = any;
type ProfileMigration = any;

glob LEGACY_TOOL_ROOTS: any = rec(
    kimi=[rec(root=".kimi", needsConsent=False)],
    devin=[rec(root=".windsurf", needsConsent=True)],
    codex=[rec(root=".codex", needsConsent=False, timing="after-generation")],
    antigravity=[rec(root=".agent", needsConsent=False, timing="after-generation")],
);

def:priv linkOf(view: any, p: str) -> any {
    return None if missing(view["linkTarget"]) else view.linkTarget(p);
}

def:priv splitPath(p: str) -> any {
    return globalThis.String.prototype.split.call(p, rx("[\\\\/]"));
}

def:priv isSamePath(a: str, b: str) -> bool {
    try {
        return realpathSync(a) == realpathSync(b);
    } except Exception {
        return False;
    }
}

def:priv areProjectArtifacts(projectPath: str, *artifactPaths: str) -> bool {
    try {
        for artifactPath in artifactPaths {
            FileSystemUtils.assertProjectArtifactPath(projectPath, artifactPath);
        }
        return True;
    } except Exception {
        return False;
    }
}

def:priv removeDirIfEmpty(dirPath: str) {
    try {
        if len(readdirSync(dirPath)) == 0 {
            rmdirSync(dirPath);
        }
    } except Exception {}
}

def:priv classifyManagedFile(source: str, destination: str, view: any) -> str {
    if isSamePath(source, destination) {
        return "skip";
    }
    if not view.exists(destination) {
        return "move";
    }
    try {
        isSkillFile = path.basename(source) == "SKILL.md"
            and path.basename(destination) == "SKILL.md";
        return "drop"
            if isRedundantLegacyCopy(
                readFileSync(source, "utf-8"), view.read(destination), isSkillFile
            )
            else "keep";
    } except Exception {
        return "keep";
    }
}

def legacyCommandPath(commandPath: str, currentRoot: str, legacyRoot: str) -> any {
    if path.isAbsolute(commandPath) {
        return None;
    }
    segments = splitPath(commandPath);
    if segments[0] != currentRoot {
        return None;
    }
    segments[0] = legacyRoot;
    return path.join(*segments);
}

def findLegacyToolMigrations(projectPath: str, timing: str = "before-generation") -> list[any] {
    return collectLegacyToolMigrations(projectPath, False, None, timing);
}

def planLegacyToolMigrations(projectPath: str, timing: str, toolIds: any, view: any) -> list[any] {
    ops: list[any] = [];
    collectLegacyToolMigrations(projectPath, False, toolIds, timing, rec(view=view, ops=ops));
    return ops;
}

def migrateLegacyToolDirs(
    projectPath: str, toolIds: any = None, timing: str = "before-generation"
) -> list[any] {
    return collectLegacyToolMigrations(projectPath, True, toolIds, timing);
}

def:priv settle(c: any, counter: str, source: str, destination: str, warning: str) {
    if c.requireDestination and not c.view.exists(destination) {
        return;
    }
    if not areProjectArtifacts(c.projectPath, source, destination) {
        globalThis.console.warn(warning);
        return;
    }
    disposition = classifyManagedFile(source, destination, c.view);
    if disposition == "skip" {
        return;
    }
    if disposition == "keep" {
        c.kept += 1;
        return;
    }
    if not c.apply {
        if not missing(c.sink) {
            c.sink.ops.append(
                rec(
                    toolId=c.sink.toolId,
                    source=source,
                    destination=destination,
                    disposition=disposition,
                    needsConsent=c.sink.needsConsent,
                ),
            );
        }
        c[counter] += 1;
        return;
    }
    try {
        if disposition == "drop" {
            rmSync(source, rec(force=True));
        } else {
            mkdirSync(path.dirname(destination), rec(recursive=True));
            renameSync(source, destination);
        }
        if counter == "skillDirs" {
            removeDirIfEmpty(path.dirname(source));
        }
        c[counter] += 1;
    } except Exception {}
}

def:priv migrateSkillDirs(c: any, currentRoot: str, legacyRoot: str) {
    legacySkillsDir = path.join(c.projectPath, legacyRoot, "skills");
    if not existsSync(legacySkillsDir) {
        return;
    }
    for workflowId in SKILL_WORKFLOWS {
        dirName = WORKFLOW_TO_SKILL_DIR[workflowId];
        source = path.join(legacySkillsDir, dirName);
        sourceSkill = path.join(source, "SKILL.md");
        if linkOf(c.view, source) is not None or not c.view.exists(sourceSkill) {
            continue;
        }
        settle(
            c,
            "skillDirs",
            sourceSkill,
            path.join(c.projectPath, currentRoot, "skills", dirName, "SKILL.md"),
            f"Skipping legacy {legacyRoot}/skills/{dirName} migration because it resolves outside this project.",
        );
    }
}

def:priv migrateCommandFiles(c: any, tool: any, legacyRoot: str) {
    adapter = CommandAdapterRegistry.get(tool.value);
    if not adapter or not tool["skillsDir"] {
        return;
    }
    for commandId in COMMAND_IDS {
        currentPath = adapter.getFilePath(commandId);
        legacyPath = legacyCommandPath(currentPath, tool.skillsDir, legacyRoot);
        if not legacyPath {
            continue;
        }
        source = FileSystemUtils.resolveProjectArtifactPath(c.projectPath, legacyPath);
        if not existsSync(source) {
            continue;
        }
        settle(
            c,
            "commandFiles",
            source,
            FileSystemUtils.resolveProjectArtifactPath(
                c.projectPath, splitPath(currentPath).join(path.sep)
            ),
            f"Skipping legacy {legacyPath} migration because it resolves outside this project.",
        );
    }
}

def:priv collectLegacyToolMigrations(
    projectPath: str, apply: bool, toolIds: any, timing: str, plan: any = None
) -> list[any] {
    migrations: list[any] = [];
    for tool in AI_TOOLS {
        if not tool["skillsDir"] or (not missing(toolIds) and tool.value not in toolIds) {
            continue;
        }
        for legacy in LEGACY_TOOL_ROOTS[tool.value] ?? [] {
            legacyTiming = legacy["timing"] ?? "before-generation";
            if legacyTiming != timing
                or legacy.root == tool.skillsDir
                or (apply and missing(toolIds) and legacy.needsConsent)
            {
                continue;
            }
            legacyRootPath = path.join(projectPath, legacy.root);
            if not existsSync(legacyRootPath) {
                continue;
            }
            if not areProjectArtifacts(
                projectPath, legacyRootPath, path.join(projectPath, tool.skillsDir)
            ) {
                globalThis.console.warn(
                    f"Skipping legacy {legacy.root}/ migration because the directory resolves outside this project.",
                );
                continue;
            }
            c = rec(
                projectPath=projectPath,
                apply=apply,
                requireDestination=legacyTiming == "after-generation",
                view=at(plan, "view") ?? DISK_VIEW,
                sink=merge(plan, rec(toolId=tool.value, needsConsent=legacy.needsConsent))
                    if not missing(plan)
                    else None,
                skillDirs=0,
                commandFiles=0,
                kept=0,
            );
            migrateSkillDirs(c, tool.skillsDir, legacy.root);
            migrateCommandFiles(c, tool, legacy.root);
            if apply {
                for dir in [
                    path.join(legacyRootPath, "skills"),
                    path.join(legacyRootPath, "workflows"),
                    legacyRootPath,
                ] {
                    removeDirIfEmpty(dir);
                }
            }
            if c.skillDirs > 0 or c.commandFiles > 0 or c.kept > 0 {
                migrations.append(
                    rec(
                        **{
                            "toolId": tool.value,
                            "from": legacy.root,
                            "to": tool.skillsDir,
                            "skillDirs": c.skillDirs,
                            "commandFiles": c.commandFiles,
                            "keptInPlace": c.kept,
                            "needsConsent": legacy.needsConsent,
                        },
                    ),
                );
            }
        }
    }
    return migrations;
}

def:priv plural(n: int, word: str) -> str {
    return f"{n} {word}{'' if n == 1 else 's'}";
}

def describeLegacyMigration(migration: any) -> str {
    parts: list[str] = [];
    if migration.skillDirs > 0 {
        parts.append(plural(migration.skillDirs, "skill"));
    }
    if migration.commandFiles > 0 {
        parts.append(plural(migration.commandFiles, "command"));
    }
    return " and ".join(parts);
}

def keptInPlaceNotice(migration: any) -> any {
    n = migration.keptInPlace;
    if n == 0 {
        return None;
    }
    return f"Left {plural(n, 'file')} in {migration['from']}/ that differ{'s' if n == 1 else ''} from the copy in {migration.to}/. Nothing was overwritten — compare the two and delete the {migration['from']}/ copy once you have kept anything you customized.";
}

def hasMovableContent(migration: any) -> bool {
    return migration.skillDirs > 0 or migration.commandFiles > 0;
}

def legacyMigrationNotice(migration: any) -> str {
    (src, dst) = (migration["from"], migration.to);
    if migration.toolId == "devin" {
        return f"Windsurf is now Devin Desktop, and its config directory moved from {src}/ to {dst}/. Devin Desktop reads {src}/ only as a fallback, and Devin Local does not read it at all.";
    }
    return f"{src}/ is the former location for this tool; {dst}/ is current.";
}

def:priv scanInstalledWorkflowArtifacts(
    projectPath: str, tools: any, includeLegacyRoots: bool, view: any
) -> any {
    installed: set[str] = set();
    hasSkills = False;
    hasCommands = False;
    for tool in tools {
        if not toolSupportsSkills(tool) {
            continue;
        }
        skillsDirs: list[any] = [];
        if tool["globalSkillsDir"] or not usesSharedSkills(tool) {
            skillsDirs.append(resolveToolSkillsDir(projectPath, tool));
        } else {
            if isToolListed(projectPath, tool.value, view) {
                skillsDirs.append(resolveToolSkillsDir(projectPath, tool));
            }
            former = resolveFormerOwnSkillsDir(projectPath, tool);
            if former {
                skillsDirs.append(former);
            }
            if includeLegacyRoots {
                skillsDirs.extend([
                    path.join(projectPath, r, "skills")
                    for r in tool["legacySkillsDirs"] or []
                ]);
            }
        }
        for skillsDir in skillsDirs {
            for workflowId in ALL_WORKFLOWS {
                if view.exists(
                    path.join(skillsDir, WORKFLOW_TO_SKILL_DIR[workflowId], "SKILL.md")
                ) {
                    installed.add(workflowId);
                    hasSkills = True;
                }
            }
        }
        adapter = CommandAdapterRegistry.get(tool.value);
        if not adapter {
            continue;
        }
        legacyRoots = [l.root for l in LEGACY_TOOL_ROOTS[tool.value] ?? []]
            if includeLegacyRoots
            else [];
        for workflowId in ALL_WORKFLOWS {
            commandPath = adapter.getFilePath(workflowId);
            candidates: list[any] = [commandPath];
            if tool["skillsDir"] {
                for r in legacyRoots {
                    legacyPath = legacyCommandPath(commandPath, tool.skillsDir, r);
                    if legacyPath {
                        candidates.append(legacyPath);
                    }
                }
            }
            for candidate in candidates {
                if view.exists(
                    candidate if path.isAbsolute(candidate) else path.join(projectPath, candidate)
                ) {
                    installed.add(workflowId);
                    hasCommands = True;
                    break;
                }
            }
        }
    }
    return rec(
        workflows=[w for w in ALL_WORKFLOWS if w in installed],
        hasSkills=hasSkills,
        hasCommands=hasCommands,
    );
}

def scanInstalledWorkflows(projectPath: str, tools: any, view: any = None) -> list[any] {
    return scanInstalledWorkflowArtifacts(projectPath, tools, False, view ?? DISK_VIEW).workflows;
}

def computeProfileMigration(projectPath: str, tools: any, view: any = None) -> any {
    if isGlobalConfigUnreadable() {
        return JsNull;
    }
    configPath = getGlobalConfigPath();
    rawConfig: any = rec();
    try {
        if existsSync(configPath) {
            rawConfig = globalThis.JSON.parse(readFileSync(configPath, "utf-8"));
        }
    } except Exception {
        return JsNull;
    }
    if at(rawConfig, "profile") is not None {
        return JsNull;
    }
    installed = scanInstalledWorkflowArtifacts(
        projectPath, tools, True, view ?? DISK_VIEW
    ).workflows;
    if len(installed) == 0 {
        return JsNull;
    }
    isCore = len(installed) == len(CORE_WORKFLOWS)
        and len([w for w in CORE_WORKFLOWS if w in installed]) == len(CORE_WORKFLOWS);
    return rec(profile="core" if isCore else "custom", workflows=installed);
}

def applyProfileMigration(migration: any) -> any {
    config = getGlobalConfig();
    config.profile = migration.profile;
    config.workflows = migration.workflows;
    rawDelivery: any = None;
    try {
        rawDelivery = at(
            globalThis.JSON.parse(readFileSync(getGlobalConfigPath(), "utf-8")), "delivery"
        );
    } except Exception {}
    if rawDelivery is None {
        globalThis.Reflect.deleteProperty(config, "delivery");
    }
    return config;
}

def migrateIfNeeded(projectPath: str, tools: any) {
    migration = computeProfileMigration(projectPath, tools);
    if missing(migration) {
        return;
    }
    saveGlobalConfig(applyProfileMigration(migration));
    if migration.profile == "core" {
        return;
    }
    globalThis.console.log(f"Migrated: custom profile with {len(migration.workflows)} workflows");
    references = globalThis.Array.from(
        new(
            globalThis.Set,
            [getSkillReferenceTransformer(tool.value)("/opsx:propose") for tool in tools],
        ),
    );
    reference = references[0] if len(references) == 1 else "the openspec-propose skill";
    globalThis.console.log(
        f"New in this version: {reference}. Try 'openspec config profile core' for the streamlined experience.",
    );
}
