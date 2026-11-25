import from "node:path" { default as path }

type SkillName = any;
type CommandId = any;
type ToolSkillStatus = any;
type ToolVersionStatus = any;

glob SKILL_NAMES: any = OPENSPEC_SKILL_NAMES,
     COMMAND_IDS: list[str] = "explore new continue apply update ff sync archive bulk-archive verify onboard propose".split();

def:priv hasSkillIn(view: any, dirs: list[any], name: str) -> bool {
    for dir in dirs {
        if view.exists(path.join(dir, name, "SKILL.md")) {
            return True;
        }
    }
    return False;
}

def getToolsWithSkillsDir -> list[str] {
    return [tool.value for tool in getSkillCapableTools()];
}

def isListedToolPresent(projectRoot: str, toolId: str, view: any = None) -> bool {
    view = view ?? DISK_VIEW;
    tool = findTool(toolId);
    if not tool or not usesSharedSkills(tool) or not isToolListed(projectRoot, toolId, view) {
        return False;
    }
    if not readListedToolsWithOwnFiles(projectRoot, view).has(toolId)
        or toolHasAnyConfiguredCommand(projectRoot, toolId, view)
    {
        return True;
    }
    linkDir = resolveSkillLinkDir(projectRoot, tool)
        ?? resolveFormerOwnSkillsDir(projectRoot, tool);
    for name in OPENSPEC_SKILL_NAMES {
        if linkDir is not None and hasSkillIn(view, [linkDir], name) {
            return True;
        }
    }
    return hasSkillLinks(projectRoot, tool, view);
}

def hasSkillLinks(projectRoot: str, tool: any, view: any = None) -> bool {
    view = view ?? DISK_VIEW;
    linkDir = resolveSkillLinkDir(projectRoot, tool);
    if not linkDir {
        return False;
    }
    sharedDir = resolveSharedSkillsDir(projectRoot);
    for name in OPENSPEC_SKILL_NAMES {
        spot = path.join(linkDir, name);
        target = path.join(sharedDir, name);
        if (
            classifySkillLinkSpot(spot, target, [], view) == "link"
                if linkOf(view, spot) is not None
                else view.exists(spot)
                    and not view.isDirectory(spot)
                    and isCheckedOutLink(spot, target, view)
        ) {
            return True;
        }
    }
    return False;
}

def:priv skillDirsForTool(projectRoot: str, tool: any, view: any) -> list[any] {
    dirs: list[any] = [];
    if not usesSharedSkills(tool) {
        dirs.append(resolveToolSkillsDir(projectRoot, tool));
    } else {
        former = resolveFormerOwnSkillsDir(projectRoot, tool);
        target = resolveSkillLinkDir(projectRoot, tool);
        if target {
            dirs.append(target);
        }
        if isListedToolPresent(projectRoot, tool.value, view) {
            dirs.append(resolveSharedSkillsDir(projectRoot));
        }
        if former and former != target {
            dirs.append(former);
        }
    }
    dirs.extend([path.join(projectRoot, r, "skills") for r in tool["legacySkillsDirs"] or []]);
    return dirs;
}

def getToolSkillStatus(projectRoot: str, toolId: str, view: any = None) -> any {
    view = view ?? DISK_VIEW;
    tool = findTool(toolId);
    if not tool or not toolSupportsSkills(tool) {
        return rec(configured=False, fullyConfigured=False, skillCount=0);
    }
    dirs = skillDirsForTool(projectRoot, tool, view);
    skillCount = len([name for name in SKILL_NAMES if hasSkillIn(view, dirs, name)]);
    return rec(
        configured=skillCount > 0,
        fullyConfigured=skillCount == len(SKILL_NAMES),
        skillCount=skillCount,
    );
}

def toolHasAnyConfiguredCommand(projectPath: str, toolId: str, view: any = None) -> bool {
    view = view ?? DISK_VIEW;
    adapter = CommandAdapterRegistry.get(toolId);
    if not adapter {
        return False;
    }
    for commandId in COMMAND_IDS {
        cmdPath = adapter.getFilePath(commandId);
        if view.exists(cmdPath if path.isAbsolute(cmdPath) else path.join(projectPath, cmdPath)) {
            return True;
        }
    }
    return False;
}

def normalizeCommandContent(content: str) -> str {
    return sub(sub(content, "^\\uFEFF", "", ""), "\\r\\n", "\n");
}

glob getToolStates: any = new(globalThis.Function, "f", "return (...a) => new Map(f(...a))")(
    lambda (projectRoot: str) -> any {
        return [
            [
                tool.value,
                merge(
                    getToolSkillStatus(projectRoot, tool.value),
                    rec(configured=True) if isListedToolPresent(projectRoot, tool.value) else rec(),
                ),
            ]
            for tool in getSkillCapableTools()
        ];
    },
);

def extractGeneratedByVersion(skillFilePath: str, view: any = None) -> any {
    view = view ?? DISK_VIEW;
    try {
        if not view.exists(skillFilePath) {
            return JsNull;
        }
        for line in splitBy(view.read(skillFilePath), "\\r\\n?|\\n") {
            hit: any = matchOf(line, "^[ \\t]*generatedBy:[ \\t]*[\"']?([^\"'\\n]+)[\"']?[ \\t]*$");
            if hit is not JsNull and hit[1] {
                return hit[1].trim();
            }
        }
    } except Exception {}
    return JsNull;
}

def:priv isPublishedSkillText(
    skillName: str, skillFile: str, version: str, view: any, toolId: str
) -> bool {
    try {
        text = normalizeGeneratedContent(view.read(skillFile));
        source = expectedSkillContents(version).get(skillName);
        return source is not None and projectSkillText(toolId, source) == text;
    } except Exception {
        return False;
    }
}

def getToolVersionStatus(
    projectRoot: str, toolId: str, currentVersion: str, options: any = None
) -> any {
    view = at(options, "view") ?? DISK_VIEW;
    tool = findTool(toolId);
    if not tool or not toolSupportsSkills(tool) {
        return rec(
            toolId=toolId,
            toolName=toolId,
            configured=False,
            generatedByVersion=JsNull,
            needsUpdate=False,
        );
    }
    ownDir = resolveSkillLinkDir(projectRoot, tool);
    version: any = JsNull;
    dirs = skillDirsForTool(projectRoot, tool, view);
    found = [
        (name, dir)
        for name in SKILL_NAMES
        for dir in dirs
        if view.exists(path.join(dir, name, "SKILL.md"))
    ];
    if found {
        (name, dir) = found[0];
        skillFile = path.join(dir, name, "SKILL.md");
        version = extractGeneratedByVersion(skillFile, view);
        if version is JsNull
            and usesSharedSkills(tool)
            and isPublishedSkillText(
                name, skillFile, currentVersion, view, toolId if dir == ownDir else "openspec"
            )
        {
            version = currentVersion;
        }
    }
    configured = getToolSkillStatus(projectRoot, toolId, view).configured
        or toolHasAnyConfiguredCommand(projectRoot, toolId, view)
        or isListedToolPresent(projectRoot, toolId, view)
        or hasSkillLinks(projectRoot, tool, view);
    return rec(
        toolId=toolId,
        toolName=tool.name,
        configured=configured,
        generatedByVersion=version,
        needsUpdate=configured and (version is JsNull or version != currentVersion),
    );
}

def:priv hasLegacyCommands(projectRoot: str, toolId: str, view: any) -> bool {
    tool = findTool(toolId);
    adapter = CommandAdapterRegistry.get(toolId);
    if not at(tool, "skillsDir") or not adapter {
        return False;
    }
    for legacyRoot in tool["legacySkillsDirs"] or [] {
        for commandId in COMMAND_IDS {
            commandPath = adapter.getFilePath(commandId);
            segments: any = splitBy(commandPath, "[\\\\/]");
            if path.isAbsolute(commandPath) or segments[0] != tool.skillsDir {
                continue;
            }
            segments[0] = legacyRoot;
            file = path.join(projectRoot, *segments);
            try {
                FileSystemUtils.assertProjectArtifactPath(projectRoot, file);
                if view.exists(file) {
                    return True;
                }
            } except Exception {}
        }
    }
    return False;
}

def:priv isConfigured(projectRoot: str, t: any, listed: list[any], view: any) -> bool {
    if not toolSupportsSkills(t) {
        return False;
    }
    aliases: any = agentsByProjectFolder.get(installerAgent(t.value).projectSkillsDir);
    if aliases and len(aliases) > 1 and t.value not in listed {
        if t.value != aliases[0] or len([id for id in aliases if id in listed]) > 0 {
            return False;
        }
    }
    return getToolSkillStatus(projectRoot, t.value, view).configured
        or toolHasAnyConfiguredCommand(projectRoot, t.value, view)
        or (
            resolveCommandSurfaceCapability(t.value) == "adapter-backed"
            and (
                hasLegacySkills(projectRoot, t, view)
                or hasLegacyCommands(projectRoot, t.value, view)
            )
        )
        or isListedToolPresent(projectRoot, t.value, view)
        or hasSkillLinks(projectRoot, t, view);
}

def getConfiguredTools(projectRoot: str, view: any = None) -> list[str] {
    view = view ?? DISK_VIEW;
    listed = readSkillToolList(projectRoot, view);
    return [t.value for t in AI_TOOLS if isConfigured(projectRoot, t, listed, view)];
}

def getAllToolVersionStatus(projectRoot: str, currentVersion: str) -> list[any] {
    return [
        getToolVersionStatus(projectRoot, toolId, currentVersion)
        for toolId in getConfiguredTools(projectRoot)
    ];
}
