import from "node:path" { default as path }

def:priv splitOn(text: any, pattern: str) -> any {
    return splitBy(text, pattern);
}

def:priv markerLines(projectPath: str, view: any) -> list[any] {
    marker = skillToolListPath(projectPath);
    FileSystemUtils.assertProjectArtifactPath(projectPath, marker);
    return [
        splitOn(line.trim(), "\\s+")
        for line in splitOn(view.read(marker) if view.exists(marker) else "", "\\r?\\n")
    ];
}

def:priv sharedDir(projectPath: str) -> str {
    return path.join(projectPath, SHARED_SKILLS_ROOT, "skills");
}

def skillToolListPath(projectPath: str) -> str {
    return path.join(sharedDir(projectPath), ".openspec-target");
}

def formatSkillToolList(toolIds: any, toolsWithOwnFiles: any = None) -> str {
    withOwn = toolsWithOwnFiles ?? new(globalThis.Set);
    return "".join([
        (f"{id} own-files" if withOwn.has(id) else id) + "\n"
        for id in sorted(globalThis.Array.from(new(globalThis.Set, toolIds)))
    ]);
}

def readListedToolsWithOwnFiles(projectPath: str, view: any = DISK_VIEW) -> any {
    try {
        ids = [
            resolveToolIdAlias(t[0])
            for t in markerLines(projectPath, view)
            if len(t) > 1 and t[1] == "own-files"
        ];
    } except Exception {
        ids = [];
    }
    return new(globalThis.Set, ids);
}

def:priv inferPreListTool(projectPath: str, view: any) -> any {
    if not view.exists(sharedDir(projectPath)) {
        return None;
    }
    foundGenericReference = False;
    for skillName in OPENSPEC_SKILL_NAMES {
        skillFile = path.join(sharedDir(projectPath), skillName, "SKILL.md");
        if not view.exists(skillFile) {
            continue;
        }
        try {
            FileSystemUtils.assertProjectArtifactPath(projectPath, skillFile);
            content: str = view.read(skillFile);
            if not isReleasedGeneratedContent(content) {
                continue;
            }
            if "$openspec-" in content {
                return "codex";
            }
            if "/openspec-" in content {
                foundGenericReference = True;
            }
        } except Exception {}
    }
    return "agents" if foundGenericReference else None;
}

def:priv readListFileTools(projectPath: str, view: any) -> list[any] {
    try {
        ids = [resolveToolIdAlias(t[0]) for t in markerLines(projectPath, view)];
        return [id for id in ids if findTool(id) is not None];
    } except Exception {
        return [];
    }
}

def readSkillToolList(projectPath: str, view: any = DISK_VIEW) -> list[any] {
    listed = readListFileTools(projectPath, view);
    if listed {
        return listed;
    }
    inferred = inferPreListTool(projectPath, view) ?? inferSkillsLockTool(projectPath, view);
    return [inferred] if inferred else [];
}

def:priv inferSkillsLockTool(projectPath: str, view: any) -> any {
    try {
        lockFile = path.join(projectPath, "skills-lock.json");
        FileSystemUtils.assertProjectArtifactPath(projectPath, lockFile);
        if not view.exists(lockFile) {
            return None;
        }
        skills = globalThis.JSON.parse(view.read(lockFile))["skills"] ?? rec();
        fromOpenSpec = [
            name
            for name in OPENSPEC_SKILL_NAMES
            if isOpenSpecSource(at(skills, name, "source"))
        ];
        return "agents"
            if fromOpenSpec
                and hasOpenSpecSkillIn(projectPath, sharedDir(projectPath), view, fromOpenSpec)
            else None;
    } except Exception {
        return None;
    }
}

def:priv isOpenSpecSource(source: any) -> bool {
    if kind(source) != "string" {
        return False;
    }
    repo = source.trim().toLowerCase();
    for pattern in ["^(?:https?:\\/\\/|git@)github\\.com[/:]", "\\/+$", "\\/skills$", "\\.git$"] {
        repo = sub(repo, pattern, "", "");
    }
    return repo == "fission-ai/openspec";
}

def isToolListed(projectPath: str, toolId: str, view: any = DISK_VIEW) -> bool {
    return toolId in readSkillToolList(projectPath, view);
}

def:priv hasSkillFile(projectPath: str, skillFile: str, view: any) -> bool {
    try {
        FileSystemUtils.assertProjectArtifactPath(projectPath, skillFile);
        return view.exists(skillFile);
    } except Exception {
        return False;
    }
}

def:priv hasOpenSpecSkillIn(
    projectPath: str, skillsDir: str, view: any, names: any = OPENSPEC_SKILL_NAMES
) -> bool {
    for name in names {
        if hasSkillFile(projectPath, path.join(skillsDir, name, "SKILL.md"), view) {
            return True;
        }
    }
    return False;
}

def hasLegacySkills(projectPath: str, tool: any, view: any = DISK_VIEW) -> bool {
    for dir in tool["legacySkillsDirs"] or [] {
        if hasOpenSpecSkillIn(projectPath, path.join(projectPath, dir, "skills"), view) {
            return True;
        }
    }
    return False;
}

def hasOwnFolderSkills(projectPath: str, tool: any, view: any = DISK_VIEW) -> bool {
    ownDir = resolveFormerOwnSkillsDir(projectPath, tool);
    return ownDir is not None and hasOpenSpecSkillIn(projectPath, ownDir, view);
}
