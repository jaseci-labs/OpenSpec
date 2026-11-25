import from "node:fs" { default as nodeFs }
import from "node:os" { default as os }
import from "node:path" { default as path }
import from "node:process" { default as process }

type LegacyDetectionResult = any;
type LegacyCleanupOps = any;

glob:priv fsp: any = nodeFs.promises,
          DIR_FILES: list[str] = ["proposal.md", "apply.md", "archive.md"],
          THREE: list[str] = ["proposal", "apply", "archive"];

def:priv commandDir(tool: str, names: list[str]) -> any {
    return rec(type="directory", path=f".{tool}/commands/openspec", managedFileNames=names);
}

def:priv commandFiles(pattern: any) -> any {
    return rec(type="files", pattern=pattern);
}

glob LEGACY_CONFIG_FILES: list[str] = "CLAUDE.md CLINE.md CODEBUDDY.md COSTRICT.md QODER.md IFLOW.md AGENTS.md QWEN.md".split(),
     LEGACY_SLASH_COMMAND_PATHS: any = globalThis.Object.fromEntries([
         [tool, ent]
         for (tool, ent) in zip(
             "claude codebuddy qoder lingma crush gemini cursor devin kilocode kiro github-copilot amazon-q cline roocode auggie factory opencode continue antigravity iflow qwen codex costrict".split(),
             [
                 commandDir("claude", DIR_FILES),
                 commandDir("codebuddy", DIR_FILES),
                 commandDir("qoder", DIR_FILES),
                 commandDir("lingma", []),
                 commandDir("crush", DIR_FILES),
                 commandDir("gemini", ["proposal.toml", "apply.toml", "archive.toml"]),
                 commandFiles(".cursor/commands/openspec-*.md"),
                 commandFiles(".windsurf/workflows/openspec-*.md"),
                 commandFiles(
                     [f".kilocode/workflows/opsx-{w}.md" for w in ALL_WORKFLOWS] + [
                         f".kilocode/workflows/openspec-{n}.md"
                         for n in THREE
                     ],
                 ),
                 commandFiles(".kiro/prompts/openspec-*.prompt.md"),
                 commandFiles(".github/prompts/openspec-*.prompt.md"),
                 commandFiles(".amazonq/prompts/openspec-*.md"),
                 commandFiles(
                     [".clinerules/workflows/openspec-*.md"] + [
                         f".clinerules/openspec-{n}.md"
                         for n in THREE
                     ],
                 ),
                 commandFiles(".roo/commands/openspec-*.md"),
                 commandFiles(".augment/commands/openspec-*.md"),
                 commandFiles(".factory/commands/openspec-*.md"),
                 commandFiles([".opencode/command/opsx-*.md", ".opencode/command/openspec-*.md"]),
                 commandFiles(".continue/prompts/openspec-*.prompt"),
                 commandFiles(".agent/workflows/openspec-*.md"),
                 commandFiles(".iflow/commands/openspec-*.md"),
                 commandFiles(
                     [".qwen/commands/opsx-*.toml", ".qwen/commands/openspec-*.toml"] + [
                         f".qwen/commands/openspec-{n}.md"
                         for n in THREE
                     ],
                 ),
                 commandFiles(".codex/prompts/openspec-*.md"),
                 commandFiles(".cospec/openspec/commands/openspec-*.md"),
             ],
         )
     ]),
     LEGACY_GLOBAL_SLASH_COMMAND_PATHS: any = rec(
         codex=rec(
             managedFileNames=[
                 f"opsx-{w}.md"
                 for w in "propose explore new continue apply update ff sync archive bulk-archive verify onboard".split()
             ],
             workflowIdsByFileName=globalThis.Object.fromEntries([
                 [f"opsx-{w}.md", [w]]
                 for w in "propose explore new continue apply update ff sync archive bulk-archive verify onboard".split()
             ]),
             resolvePromptDir=getCodexPromptDir,
             replacementLabel="Codex skills",
         ),
     );

glob:priv DIRECT_CLEANUP_OPS: any = rec(
    writeFile=lambda (filePath: str, content: str) -> any {
        FileSystemUtils.writeFile(filePath, content)
    },
    removeFile=lambda (filePath: str) -> any { fsp.unlink(filePath) },
    removeEmptyDirectory=lambda (dirPath: str) -> any { fsp.rmdir(dirPath) },
);

def getCodexPromptDir -> str {
    envHome: any = process.env["CODEX_HOME"];
    envHome = envHome.trim() if envHome is not None else "";
    return path.join(path.resolve(envHome or path.join(os.homedir(), ".codex")), "prompts");
}

def:priv splitOn(text: any, pattern: str) -> any {
    return globalThis.String.prototype.split.call(text, rx(pattern));
}

def:priv globMatches(pattern: str, file: str) -> bool {
    return found(file, "^" + sub(sub(pattern, "[.+^${}()|[\\]\\\\]", "\\$&"), "\\*", ".*") + "$");
}

def:priv asList(pattern: any) -> list[any] {
    return pattern if globalThis.Array.isArray(pattern) else [pattern];
}

def:priv errorText(e: any) -> any {
    return js_error(e).message;
}

def:priv chalk -> any {
    return pick("chalk");
}

def:priv getManagedGlobalLegacyPromptMetadata(filePath: str) -> any {
    if not path.isAbsolute(filePath) {
        return None;
    }
    resolvedPath = path.resolve(filePath);
    for toolId in globalThis.Object.keys(LEGACY_GLOBAL_SLASH_COMMAND_PATHS) {
        pattern = LEGACY_GLOBAL_SLASH_COMMAND_PATHS[toolId];
        if path.dirname(resolvedPath) != path.resolve(pattern.resolvePromptDir()) {
            continue;
        }
        name = path.basename(resolvedPath);
        if name in pattern.managedFileNames {
            return rec(
                path=resolvedPath,
                toolId=toolId,
                managedFileName=name,
                workflowIds=at(pattern, "workflowIdsByFileName", name) ?? [],
                replacementLabel=pattern["replacementLabel"],
            );
        }
    }
    return None;
}

def:priv hasLegacyArtifacts(d: any) -> bool {
    return len(d.configFiles) > 0
        or len(d.slashCommandDirs) > 0
        or len(d.slashCommandFiles) > 0
        or len(d.globalSlashCommandFiles) > 0
        or truthy(d.hasOpenspecAgents)
        or truthy(d.hasRootAgentsWithMarkers)
        or truthy(d.hasProjectMd);
}

async def detectLegacyArtifacts(projectPath: str) -> any {
    config = await detectLegacyConfigFiles(projectPath);
    slash = await detectLegacySlashCommands(projectPath);
    details = await detectLegacyGlobalPromptFiles();
    structure = await detectLegacyStructureFiles(projectPath);
    result = rec(
        configFiles=config.allFiles,
        configFilesToUpdate=config.filesToUpdate,
        slashCommandDirs=slash.directories,
        slashCommandFiles=unique(slash.files),
        globalSlashCommandFiles=[detail.path for detail in details],
        globalSlashCommandDetails=details,
        hasOpenspecAgents=structure.hasOpenspecAgents,
        hasProjectMd=structure.hasProjectMd,
        hasRootAgentsWithMarkers=structure.hasRootAgentsWithMarkers,
        hasLegacyArtifacts=False,
    );
    result.hasLegacyArtifacts = hasLegacyArtifacts(result);
    return result;
}

async def detectLegacyConfigFiles(projectPath: str) -> any {
    files: list[str] = [];
    for fileName in LEGACY_CONFIG_FILES {
        filePath = FileSystemUtils.joinPath(projectPath, fileName);
        if await FileSystemUtils.fileExists(filePath)
            and hasOpenSpecMarkers(await FileSystemUtils.readFile(filePath))
        {
            files.append(fileName);
        }
    }
    return rec(allFiles=files, filesToUpdate=list(files));
}

async def detectLegacySlashCommands(projectPath: str) -> any {
    directories: list[str] = [];
    files: list[str] = [];
    for pattern in globalThis.Object.values(LEGACY_SLASH_COMMAND_PATHS) {
        if pattern.type == "directory" and pattern["path"] {
            dir = pattern.path;
            if not await FileSystemUtils.directoryExists(FileSystemUtils.joinPath(projectPath, dir))
                or not await reachesWithoutLink(projectPath, dir)
            {
                continue;
            }
            entries = await readLegacyCommandDir(
                FileSystemUtils.joinPath(projectPath, dir), pattern["managedFileNames"] ?? []
            );
            if entries is None {
                continue;
            }
            if len(entries.others) == 0 {
                directories.append(dir);
            } else {
                files.extend([f"{dir}/{name}" for name in entries.managed]);
            }
        } elif pattern.type == "files" and pattern["pattern"] {
            for p in asList(pattern.pattern) {
                files.extend(await findLegacySlashCommandFiles(projectPath, p));
            }
        }
    }
    return rec(directories=directories, files=files);
}

async def:priv readLegacyCommandDir(dirPath: str, managedFileNames: any) -> any {
    try {
        if (await fsp.lstat(dirPath)).isSymbolicLink() {
            return None;
        }
        entries = await fsp.readdir(dirPath, rec(withFileTypes=True));
    } except Exception {
        return None;
    }
    managed: list[str] = [];
    others: list[str] = [];
    for ent in entries {
        if ent.isFile()
            and ent.name in managedFileNames
            and await isGeneratedLegacyCommand(path.join(dirPath, ent.name))
        {
            managed.append(ent.name);
        } else {
            others.append(f"{ent.name}/" if ent.isDirectory() else ent.name);
        }
    }
    return rec(managed=sorted(managed), others=sorted(others));
}

def:priv legacyCommandDirForFile(file: str) -> any {
    normalizedFile = file.replace("\\", "/");
    for toolId in globalThis.Object.keys(LEGACY_SLASH_COMMAND_PATHS) {
        pattern = LEGACY_SLASH_COMMAND_PATHS[toolId];
        if pattern.type != "directory" or not pattern["path"] {
            continue;
        }
        for name in pattern["managedFileNames"] ?? [] {
            if normalizedFile == f"{pattern.path}/{name}" {
                return rec(toolId=toolId, dir=pattern.path);
            }
        }
    }
    return None;
}

async def:priv settleLegacyCommandDir(
    projectPath: str, dirPath: str, result: any, ops: any = DIRECT_CLEANUP_OPS
) -> bool {
    fullPath = FileSystemUtils.joinPath(projectPath, dirPath);
    remaining = await readLegacyCommandDir(fullPath, []);
    if remaining is None {
        return False;
    }
    if len(remaining.others) == 0 {
        await ops.removeEmptyDirectory(fullPath);
        result.deletedDirs.append(dirPath);
        return True;
    }
    result.keptFiles.extend([f"{dirPath}/{name}" for name in remaining.others]);
    return False;
}

async def:priv isGeneratedLegacyCommand(filePath: str) -> bool {
    content = await readRegularFileNoFollow(filePath);
    return content is not None and hasOpenSpecMarkers(content);
}

async def reachesWithoutLink(projectPath: str, relativePath: str) -> bool {
    current = FileSystemUtils.canonicalizeExistingPath(projectPath);
    for segment in splitOn(relativePath, "[\\\\/]+") {
        if not segment {
            continue;
        }
        if segment == ".." or segment == "." {
            return False;
        }
        current = path.join(current, segment);
        try {
            if (await fsp.lstat(current)).isSymbolicLink() {
                return False;
            }
        } except Exception {
            return True;
        }
    }
    return True;
}

async def:priv readRegularFileNoFollow(filePath: str) -> any {
    c = nodeFs.constants;
    handle: any = None;
    try {
        handle = await fsp.open(
            filePath, c.O_RDONLY | (c["O_NOFOLLOW"] ?? 0) | (c["O_NONBLOCK"] ?? 0)
        );
        if c["O_NOFOLLOW"] is None and (await fsp.lstat(filePath)).isSymbolicLink() {
            return None;
        }
        if not (await handle.stat()).isFile() {
            return None;
        }
        return await handle.readFile("utf-8");
    } except Exception {
        return None;
    } finally {
        if handle is not None {
            await handle.close();
        }
    }
}

async def:priv scanGlobalPrompts -> list[any] {
    hits: list[any] = [];
    for pattern in globalThis.Object.values(LEGACY_GLOBAL_SLASH_COMMAND_PATHS) {
        promptDir = pattern.resolvePromptDir();
        try {
            for ent in await fsp.readdir(promptDir, rec(withFileTypes=True)) {
                if not ent.isFile() or ent.name not in pattern.managedFileNames {
                    continue;
                }
                fullPath = path.join(promptDir, ent.name);
                match_ = getManagedGlobalLegacyPromptMetadata(fullPath);
                if match_ is not None {
                    content = await readRegularFileNoFollow(fullPath);
                    if content is not None {
                        hits.append(
                            rec(
                                path=fullPath,
                                prompt=match_,
                                released=isReleasedGeneratedContent(content),
                            ),
                        );
                    }
                }
            }
        } except Exception {}
    }
    return hits;
}

async def:priv detectLegacyGlobalPromptFiles -> list[any] {
    return [hit.prompt for hit in await scanGlobalPrompts() if hit.released];
}

async def findEditedLegacyGlobalPrompts -> list[any] {
    return [hit.path for hit in await scanGlobalPrompts() if not hit.released];
}

async def:priv findLegacySlashCommandFiles(projectPath: str, pattern: str) -> list[str] {
    cut = max(pattern.rfind("/"), pattern.rfind("\\"));
    dirPart = pattern[:max(cut, 0)];
    filePart = pattern[cut + 1:];
    dirPath = FileSystemUtils.joinPath(projectPath, dirPart);
    if not await FileSystemUtils.directoryExists(dirPath)
        or not await reachesWithoutLink(projectPath, dirPart)
    {
        return [];
    }
    found_: list[str] = [];
    normalizedDir = dirPart.replace("\\", "/");
    try {
        for dirent in await fsp.readdir(dirPath, rec(withFileTypes=True)) {
            if dirent.isFile() and globMatches(filePart, dirent.name) {
                found_.append(f"{normalizedDir}/{dirent.name}");
            }
        }
    } except Exception {}
    return found_;
}

async def detectLegacyStructureFiles(projectPath: str) -> any {
    hasOpenspecAgents = await FileSystemUtils.fileExists(
        FileSystemUtils.joinPath(projectPath, "openspec/AGENTS.md")
    )
        and await reachesWithoutLink(projectPath, "openspec/AGENTS.md");
    hasProjectMd = await FileSystemUtils.fileExists(
        FileSystemUtils.joinPath(projectPath, "openspec/project.md")
    );
    rootAgentsPath = FileSystemUtils.joinPath(projectPath, "AGENTS.md");
    hasRootAgentsWithMarkers = await FileSystemUtils.fileExists(rootAgentsPath)
        and hasOpenSpecMarkers(await FileSystemUtils.readFile(rootAgentsPath));
    return rec(
        hasOpenspecAgents=hasOpenspecAgents,
        hasProjectMd=hasProjectMd,
        hasRootAgentsWithMarkers=hasRootAgentsWithMarkers,
    );
}

def hasOpenSpecMarkers(content: str) -> bool {
    return OPENSPEC_MARKERS.start in content and OPENSPEC_MARKERS.end in content;
}

def isOnlyOpenSpecContent(content: str) -> bool {
    start = content.find(OPENSPEC_MARKERS.start);
    end = content.find(OPENSPEC_MARKERS.end);
    if start == -1 or end == -1 or end <= start {
        return False;
    }
    before: any = content[:start];
    after: any = content[end + len(OPENSPEC_MARKERS.end):];
    return before.trim() == "" and after.trim() == "";
}

def removeMarkerBlock(content: str) -> str {
    return removeMarkerBlockUtil(content, OPENSPEC_MARKERS.start, OPENSPEC_MARKERS.end);
}

async def cleanupLegacyArtifacts(
    projectPath: str, detection: any, ops: any = DIRECT_CLEANUP_OPS
) -> any {
    result = rec(
        deletedFiles=[],
        deletedFileReplacementLabels=rec(),
        modifiedFiles=[],
        deletedDirs=[],
        keptFiles=[],
        projectMdNeedsMigration=detection.hasProjectMd,
        errors=[],
    );
    for fileName in detection.configFilesToUpdate {
        filePath = FileSystemUtils.joinPath(projectPath, fileName);
        try {
            await ops.writeFile(
                filePath, removeMarkerBlock(await FileSystemUtils.readFile(filePath))
            );
            result.modifiedFiles.append(fileName);
        } except Exception as e {
            result.errors.append(f"Failed to modify {fileName}: {errorText(e)}");
        }
    }
    for dirPath in detection.slashCommandDirs {
        fullPath = FileSystemUtils.joinPath(projectPath, dirPath);
        if not await reachesWithoutLink(projectPath, dirPath) {
            result.keptFiles.append(dirPath);
            continue;
        }
        try {
            entries = await readLegacyCommandDir(fullPath, legacyManagedFileNamesForDir(dirPath));
            if entries is None {
                continue;
            }
            deleted: list[str] = [];
            for name in entries.managed {
                filePath = path.join(fullPath, name);
                if await isGeneratedLegacyCommand(filePath) {
                    await ops.removeFile(filePath);
                    deleted.append(name);
                }
            }
            if not await settleLegacyCommandDir(projectPath, dirPath, result, ops) {
                result.deletedFiles.extend([f"{dirPath}/{name}" for name in deleted]);
            }
        } except Exception as e {
            result.errors.append(f"Failed to delete directory {dirPath}: {errorText(e)}");
        }
    }
    partlyCleanedDirs: list[str] = [];
    for filePath in detection.slashCommandFiles {
        fullPath = FileSystemUtils.joinPath(projectPath, filePath);
        if not await reachesWithoutLink(projectPath, filePath) {
            result.keptFiles.append(filePath);
            continue;
        }
        try {
            commandDir_ = legacyCommandDirForFile(filePath);
            if commandDir_ is not None {
                if commandDir_.dir not in partlyCleanedDirs {
                    partlyCleanedDirs.append(commandDir_.dir);
                }
                if not await isGeneratedLegacyCommand(fullPath) {
                    continue;
                }
            }
            await ops.removeFile(fullPath);
            result.deletedFiles.append(filePath);
        } except Exception as e {
            result.errors.append(f"Failed to delete {filePath}: {errorText(e)}");
        }
    }
    for dirPath in partlyCleanedDirs {
        try {
            await settleLegacyCommandDir(projectPath, dirPath, result, ops);
        } except Exception as e {
            result.errors.append(f"Failed to delete directory {dirPath}: {errorText(e)}");
        }
    }
    labels = {
        prompt.path: prompt["replacementLabel"]
        for prompt in getLegacyGlobalPromptMatches(detection)
    };
    for filePath in detection.globalSlashCommandFiles {
        if getManagedGlobalLegacyPromptMetadata(filePath) is None {
            result.errors.append(f"Skipped unmanaged global prompt {filePath}");
            continue;
        }
        try {
            await ops.removeFile(filePath);
            result.deletedFiles.append(filePath);
            if labels.get(filePath) {
                result.deletedFileReplacementLabels[filePath] = labels[filePath];
            }
        } except Exception as e {
            result.errors.append(f"Failed to delete {filePath}: {errorText(e)}");
        }
    }
    if truthy(detection.hasOpenspecAgents) {
        agentsPath = FileSystemUtils.joinPath(projectPath, "openspec/AGENTS.md");
        if not await reachesWithoutLink(projectPath, "openspec/AGENTS.md") {
            result.keptFiles.append("openspec/AGENTS.md");
        } elif await FileSystemUtils.fileExists(agentsPath) {
            try {
                await ops.removeFile(agentsPath);
                result.deletedFiles.append("openspec/AGENTS.md");
            } except Exception as e {
                result.errors.append(f"Failed to delete openspec/AGENTS.md: {errorText(e)}");
            }
        }
    }
    return result;
}

def formatCleanupSummary(result: any) -> str {
    lines: list[str] = [];
    keptFiles = result["keptFiles"] ?? [];
    if result.deletedFiles or result.deletedDirs or result.modifiedFiles or keptFiles {
        lines.append("Cleaned up legacy files:");
        for file in result.deletedFiles {
            label = at(result, "deletedFileReplacementLabels", file)
                ?? at(getManagedGlobalLegacyPromptMetadata(file), "replacementLabel");
            lines.append(
                f"  ✓ Removed {file}" + (f" (replaced by {label})" if truthy(label) else "")
            );
        }
        lines.extend([
            f"  ✓ Removed {d}/ (replaced by OpenSpec skills)"
            for d in result.deletedDirs
        ]);
        lines.extend([f"  • Kept {e} (not created by OpenSpec)" for e in keptFiles]);
        lines.extend([f"  ✓ Removed OpenSpec markers from {f}" for f in result.modifiedFiles]);
    }
    if truthy(result.projectMdNeedsMigration) {
        if lines {
            lines.append("");
        }
        lines.append(formatProjectMdMigrationHint());
    }
    if result.errors {
        if lines {
            lines.append("");
        }
        lines.append("Errors during cleanup:");
        lines.extend([f"  ⚠ {e}" for e in result.errors]);
    }
    return "\n".join(lines);
}

def:priv buildRemovalsList(detection: any) -> list[any] {
    removals: list[any] = [f"{d}/" for d in detection.slashCommandDirs];
    removals.extend(detection.slashCommandFiles);
    removals.extend([prompt.path for prompt in getLegacyGlobalPromptMatches(detection)]);
    if truthy(detection.hasOpenspecAgents) {
        removals.append("openspec/AGENTS.md");
    }
    return removals;
}

async def legacyCleanupDeletesOnlyReleasedOutput(projectPath: str, detection: any) -> bool {
    files: list[str] = [];
    for dirPath in detection.slashCommandDirs {
        fullPath = FileSystemUtils.joinPath(projectPath, dirPath);
        entries = await readLegacyCommandDir(fullPath, legacyManagedFileNamesForDir(dirPath));
        if entries is None {
            return False;
        }
        files.extend([path.join(fullPath, name) for name in entries.managed]);
    }
    files.extend([FileSystemUtils.joinPath(projectPath, f) for f in detection.slashCommandFiles]);
    if truthy(detection.hasOpenspecAgents) {
        files.append(FileSystemUtils.joinPath(projectPath, "openspec/AGENTS.md"));
    }
    for file in files {
        if not await reachesWithoutLink(projectPath, path.relative(projectPath, file)) {
            return False;
        }
        content = await readRegularFileNoFollow(file);
        if content is None or not isReleasedGeneratedContent(content) {
            return False;
        }
    }
    for file in detection.configFilesToUpdate {
        content = await readRegularFileNoFollow(FileSystemUtils.joinPath(projectPath, file));
        if content is None or not hasReleasedOpenSpecBlock(content) {
            return False;
        }
    }
    return True;
}

def formatDetectionSummary(detection: any) -> str {
    removals = buildRemovalsList(detection);
    updates: list[str] = list(detection.configFilesToUpdate);
    if not removals and not updates and not truthy(detection.hasProjectMd) {
        return "";
    }
    ch = chalk();
    lines = [
        ch.bold("Upgrading to the new OpenSpec"),
        "",
        "OpenSpec now uses agent skills, the emerging standard across coding",
        "agents. This simplifies your setup while keeping everything working",
        "as before.",
        "",
    ];
    if removals {
        lines.extend([
            ch.bold("Files to remove"),
            ch.dim(
                "These files will be deleted entirely. Back up any custom content before proceeding:",
            ),
        ]);
        lines.extend([f"  • {p}" for p in removals]);
    }
    if updates {
        if removals {
            lines.append("");
        }
        lines.extend([
            ch.bold("Files to update"),
            ch.dim("OpenSpec markers will be removed, your content preserved:"),
        ]);
        lines.extend([f"  • {p}" for p in updates]);
    }
    if truthy(detection.hasProjectMd) {
        if removals or updates {
            lines.append("");
        }
        lines.append(formatProjectMdMigrationHint());
    }
    return "\n".join(lines);
}

def formatDeferredGlobalPromptSummary(detection: any) -> str {
    deferred = getLegacyGlobalPromptMatches(detection);
    if not deferred {
        return "";
    }
    ch = chalk();
    return "\n".join(
        [
            ch.bold("Deferred global prompts cleanup"),
            ch.dim(
                "These global prompts will only be removed after matching replacement skills are installed.",
            ),
        ] + [f"  • {f'{p.toolId}: ' if p.toolId else ''}{p.path}" for p in deferred],
    );
}

def getToolsFromLegacyArtifacts(detection: any) -> list[any] {
    tools = [legacyToolIdForDir(d) for d in detection.slashCommandDirs]
        + [legacyToolIdForFile(f) for f in detection.slashCommandFiles]
        + [p.toolId for p in getLegacyGlobalPromptMatches(detection)];
    return [t for t in unique([t for t in tools if t]) if missing(findRetiredTool(t))];
}

def:priv legacyToolIdForDir(dir: str) -> any {
    for toolId in globalThis.Object.keys(LEGACY_SLASH_COMMAND_PATHS) {
        pattern = LEGACY_SLASH_COMMAND_PATHS[toolId];
        if pattern.type == "directory" and same(pattern["path"], dir) {
            return toolId;
        }
    }
    return None;
}

def:priv legacyManagedFileNamesForDir(dir: str) -> any {
    normalizedDir = dir.replace("\\", "/");
    for pattern in globalThis.Object.values(LEGACY_SLASH_COMMAND_PATHS) {
        if pattern.type == "directory" and same(pattern["path"], normalizedDir) {
            return pattern["managedFileNames"] ?? [];
        }
    }
    return [];
}

def:priv legacyToolIdForFile(file: str) -> any {
    commandDir_ = legacyCommandDirForFile(file);
    if commandDir_ is not None {
        return commandDir_.toolId;
    }
    normalizedFile = file.replace("\\", "/");
    for toolId in globalThis.Object.keys(LEGACY_SLASH_COMMAND_PATHS) {
        pattern = LEGACY_SLASH_COMMAND_PATHS[toolId];
        if pattern.type != "files" or not pattern["pattern"] {
            continue;
        }
        for p in asList(pattern.pattern) {
            if globMatches(p, normalizedFile) {
                return toolId;
            }
        }
    }
    return None;
}

def getLegacyGlobalPromptMatches(detection: any) -> any {
    details = detection["globalSlashCommandDetails"];
    if not missing(details) and len(details) > 0 {
        return details;
    }
    return [
        m
        for m in [
            getManagedGlobalLegacyPromptMetadata(f)
            for f in detection.globalSlashCommandFiles
        ]
        if m is not None
    ];
}

def getLegacyWorkflowIdsForTool(detection: any, toolId: str) -> list[any] {
    return unique([
        w
        for prompt in getLegacyGlobalPromptMatches(detection)
        if prompt.toolId == toolId
        for w in prompt.workflowIds
    ]);
}

def hasRepoLocalLegacyRemovals(detection: any) -> bool {
    return len(detection.slashCommandDirs) > 0
        or len(detection.slashCommandFiles) > 0
        or truthy(detection.hasOpenspecAgents)
        or len(detection.configFilesToUpdate) > 0;
}

def omitGlobalLegacyPromptFiles(detection: any) -> any {
    nextDetection = merge(detection, rec(globalSlashCommandFiles=[], globalSlashCommandDetails=[]));
    nextDetection.hasLegacyArtifacts = hasLegacyArtifacts(nextDetection);
    return nextDetection;
}

def omitToolLegacyArtifacts(detection: any, toolIds: any) -> any {
    if len(toolIds) == 0 {
        return detection;
    }
    nextDetection = merge(
        detection,
        rec(
            slashCommandDirs=[
                d
                for d in detection.slashCommandDirs
                if (legacyToolIdForDir(d) ?? "") not in toolIds
            ],
            slashCommandFiles=[
                f
                for f in detection.slashCommandFiles
                if (legacyToolIdForFile(f) ?? "") not in toolIds
            ],
        ),
    );
    nextDetection.hasLegacyArtifacts = hasLegacyArtifacts(nextDetection);
    return nextDetection;
}

def pickGlobalLegacyPromptFiles(detection: any, filePaths: any) -> any {
    selected = [path.resolve(f) for f in filePaths];
    details = [
        d
        for d in getLegacyGlobalPromptMatches(detection)
        if path.resolve(d.path) in selected
    ];
    return rec(
        configFiles=[],
        configFilesToUpdate=[],
        slashCommandDirs=[],
        slashCommandFiles=[],
        globalSlashCommandFiles=[d.path for d in details],
        globalSlashCommandDetails=details,
        hasOpenspecAgents=False,
        hasProjectMd=False,
        hasRootAgentsWithMarkers=False,
        hasLegacyArtifacts=len(details) > 0,
    );
}

def formatProjectMdMigrationHint -> str {
    ch = chalk();
    return "\n".join(
        [
            globalThis.Reflect.get(ch, "yellow").bold("Needs your attention"),
            "  • openspec/project.md",
            ch.dim("    We won't delete this file. It may contain useful project context."),
            "",
            ch.dim("    Ask your AI assistant:"),
            "",
        ]
            + [
                ch.dim(line)
                for line in [
                    "    Review openspec/project.md and migrate its useful content to",
                    "    openspec/config.yaml. Keep context concise: include only project-wide",
                    "    facts needed during artifact creation, apply, and archive. Move",
                    "    artifact-specific guidance into rules for the matching artifacts.",
                    "    Move guidance for apply or archive into the matching operations entry.",
                    "    Leave out generic, outdated, or verbose material. Do not delete project.md.",
                ]
            ]
            + ["", ch.dim("    Review config.yaml, then delete project.md when ready.")],
    );
}
