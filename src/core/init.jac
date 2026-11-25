import from "node:path" { default as path }
import from "node:fs" { existsSync, promises as fsp }
import from "node:process" { default as process }

glob:priv DEFAULT_SCHEMA: str = "spec-driven",
          VERSION: str = need(path.join(packageRoot(), "package.json")).version,
          PROGRESS_SPINNER: any = rec(
              interval=80, frames=["░░░", "▒░░", "▒▒░", "▒▒▒", "▓▒▒", "▓▓▒", "▓▓▓", "▒▓▓", "░▒▓"]
          );

def:priv chalk -> any {
    return pick("chalk");
}

def:priv log(*args: any) {
    globalThis.console.log(*args);
}

def:priv live(target: any) -> any {
    return target;
}

def:priv configuredIn(states: any, toolId: str) -> bool {
    status = states.get(toolId) if isinstance(states, globalThis.Map) else states[toolId];
    return truthy(at(status, "configured"));
}

def:priv fail(message: str) -> any {
    return new(globalThis.Error, message);
}

def:priv unique(items: any) -> list[any] {
    return globalThis.Array.from(new(globalThis.Set, items));
}

def:priv findTool(toolId: str) -> any {
    return AI_TOOLS.find(lambda (t: any) -> bool { t.value == toolId });
}

def:priv errorMessage(e: any) -> str {
    err = js_error(e);
    return err.message if isinstance(err, globalThis.Error) else globalThis.String(err);
}

def:priv reason(e: any) -> str {
    err = js_error(e);
    return f": {err.message}" if isinstance(err, globalThis.Error) else "";
}

def:priv printBlock(lines: any) {
    log(chalk().yellow(lines[0]));
    for line in lines[1:] {
        log(chalk().dim(line));
    }
}

def:priv reportMigrations(
    projectPath: str, toolIds: any = None, timing: str = "before-generation"
) {
    for m in migrateLegacyToolDirs(projectPath, toolIds, timing) {
        if hasMovableContent(m) {
            log(chalk().dim(f"Migrated {describeLegacyMigration(m)}: {m['from']} → {m.to}"));
        }
        kept = keptInPlaceNotice(m);
        if kept {
            log(chalk().dim(kept));
        }
    }
}

async def:priv confirm(message: str, answer: bool) -> any {
    ask: any = merge(await load("@inquirer/prompts")).confirm;
    return await ask(globalThis.Object.fromEntries([["message", message], ["default", answer]]));
}

def:priv profileWorkflows(profile: any) -> any {
    cfg = getGlobalConfig();
    return withRouter(getProfileWorkflows(profile ?? cfg["profile"] ?? "core", cfg["workflows"]));
}

def:priv formatLanguageContext(language: str) -> str {
    return "\n".join([
        f"Language: {language}",
        f"All artifacts must be written in {language}.",
        "Keep OpenSpec structural headings and SHALL/MUST keywords in English.",
    ]);
}

obj InitCommand(globalThis.Object) {
    def init(options: any = None) {
        super.init();
        self.toolsArg = at(options, "tools");
        self.language = self.normalizeLanguage(at(options, "language"));
        self.force = at(options, "force") ?? False;
        self.interactiveOption = at(options, "interactive");
        self.profileOverride = at(options, "profile");
        self.animation = at(options, "animation") ?? True;
        self.copilotCloudOption = at(options, "copilotCloud");
        scope = at(options, "scope");
        if scope is not None and scope not in SKILL_SCOPES {
            raise fail(f"Invalid --scope \"{scope}\". Use global or project.");
        }
        self.scopeOption = scope;
        self.scopeIsDefault = False;
        self.pickedTools = None;
    }

    async def execute(targetPath: str) {
        projectPath = FileSystemUtils.canonicalizeExistingPath(targetPath);
        openspecPath = path.join(projectPath, OPENSPEC_DIR_NAME);
        extendMode = await self.validate(projectPath, openspecPath);
        guardRoot = findRepoPlanningRootSync(projectPath);
        integrationsOnly = False;
        if guardRoot {
            shape = classifyOpenSpecDir(guardRoot);
            pointer = shape.pointer;
            if not shape.hasPlanningShape and pointer["malformed"] {
                raise fail(
                    f"The store declaration in {pointer.filePath} is invalid ({storePointerProblem(pointer.malformed)}). Fix or remove the store: line before running openspec init.",
                );
            }
            if not shape.hasPlanningShape and pointer["value"] is not None {
                if path.resolve(guardRoot) != projectPath {
                    raise fail(
                        f"This repo's planning is externalized to store '{pointer.value}' ({pointer.filePath}). Run openspec init from the pointer repo root to install integrations.",
                    );
                }
                await resolveOpenSpecRoot(rec(startPath=projectPath));
                integrationsOnly = True;
            }
        }
        if not integrationsOnly {
            await self.assertLanguageCanBeApplied(projectPath, openspecPath);
        } elif self.language {
            raise fail(
                "--language cannot update an external store through a pointer repo. Run init in the store root, or edit the store config directly.",
            );
        }
        detectedTools = getAvailableTools(projectPath);
        self.resolveProfileOverride();
        canPrompt = live(self).canPromptInteractively();
        if (await self.resolveSkillScope(projectPath, detectedTools)) == "global" {
            if await self.setUpWithGlobalSkills(
                projectPath,
                openspecPath,
                extendMode,
                integrationsOnly,
                getToolStates(projectPath),
                detectedTools,
            ) {
                rememberProject(projectPath);
                return;
            }
        }
        deferred = None if integrationsOnly else await self.handleLegacyCleanup(projectPath);
        migrateLegacyToolDirs(projectPath);
        if extendMode {
            migrateIfNeeded(projectPath, getAvailableTools(projectPath));
        }
        if canPrompt {
            import from "../ui/welcome-screen" { showWelcomeScreen }
            await showWelcomeScreen(self.getActiveWorkflows(), rec(animate=self.animation));
        }
        toolStates = getToolStates(projectPath);
        validatedTools = self.validateTools(
            await live(self).getSelectedTools(toolStates, extendMode, detectedTools, projectPath),
            toolStates,
        );
        reportMigrations(projectPath, [t.value for t in validatedTools]);
        copilot = await self.resolveCopilotCloudDecision(projectPath, validatedTools);
        if not integrationsOnly {
            await self.createDirectoryStructure(openspecPath, extendMode);
        }
        results = await self.generateSkillsAndCommands(projectPath, validatedTools, copilot.write);
        if deferred {
            await self.finalizeDeferredLegacyCleanup(projectPath, deferred);
        }
        configStatus = "exists" if integrationsOnly else await self.createConfig(openspecPath);
        if not integrationsOnly and copilot["persist"] is not None {
            try {
                await persistCopilotCloudOptIn(projectPath, copilot.persist);
            } except Exception {}
        }
        removed = 0;
        if copilot.optedOut {
            try {
                removed = await removeCopilotCloudFiles(projectPath);
            } except Exception {}
        }
        wroteCloud = copilot.write
            and "github-copilot" in [
                t.value
                for t in [*results.createdTools, *results.refreshedTools]
            ];
        present = (await listManagedCloudFiles(projectPath)) if wroteCloud else [];
        collisions = (await findUnmanagedCloudFiles(projectPath)) if wroteCloud else [];
        rememberProject(projectPath);
        self.displaySuccessMessage(
            projectPath,
            results,
            configStatus,
            rec(
                write=copilot.write,
                skippedUndecided=copilot.skippedUndecided,
                present=present,
                collisions=collisions,
                removed=removed,
            ),
        );
        if results.failedTools {
            raise fail(
                f"OpenSpec setup failed for: {', '.join([t.name for t in results.failedTools])}"
            );
        }
    }

    def toolsKeyword -> any {
        return None if self.toolsArg is None else self.toolsArg.trim().toLowerCase();
    }

    async def resolveSkillScope(projectPath: str, detectedTools: any) -> str {
        if self.toolsKeyword() == "none" {
            return "project";
        }
        if self.scopeOption {
            return self.scopeOption;
        }
        if projectHasOwnSkills(projectPath) {
            return "project";
        }
        fromEnv: any = process.env["OPENSPEC_SKILLS_SCOPE"];
        fromEnv = None if fromEnv is None else fromEnv.trim();
        if fromEnv {
            if fromEnv not in SKILL_SCOPES {
                raise fail(f"Invalid OPENSPEC_SKILLS_SCOPE \"{fromEnv}\". Use global or project.");
            }
            return fromEnv;
        }
        saved = getGlobalConfig()["skillsScope"];
        if saved {
            return saved;
        }
        if truthy(self.copilotCloudOption) {
            return "project";
        }
        if self.toolsKeyword() != "all" {
            ids = self.resolveToolsArg() ?? [t.value for t in detectedTools];
            if [i for i in ids if not supportsGlobalSkills(i)] {
                return "project";
            }
        }
        self.scopeIsDefault = True;
        return "global";
    }

    async def setUpWithGlobalSkills(
        projectPath: str,
        openspecPath: str,
        extendMode: bool,
        integrationsOnly: bool,
        toolStates: any,
        detectedTools: any,
    ) -> bool {
        if self.copilotCloudOption is True {
            raise fail(
                "--copilot-cloud sets up the GitHub-hosted agent, which only sees skills kept in the project. Add --scope project.",
            );
        }
        if isHomeFolder(projectPath) {
            raise fail(
                "This is your home folder, where the global skills live. Run openspec init inside a project.",
            );
        }
        try {
            installed = await readGlobalSkills();
        } except Exception as e {
            raise fail(
                f"Could not read the skills installed for this machine: {describeSkillsError(js_error(e))}",
            );
        }
        movesProject = projectHasOwnSkills(projectPath);
        configured = getConfiguredTools(projectPath) if movesProject else [];
        selected = (
            await live(self).getSelectedTools(toolStates, extendMode, detectedTools, projectPath)
        )
            if self.toolsArg is not None or (not installed.skills and not movesProject)
            else configured;
        tools = self.validateTools(selected, toolStates);
        supported = [t for t in tools if supportsGlobalSkills(t.value)];
        unsupported = [t for t in tools if not supportsGlobalSkills(t.value)];
        if self.scopeIsDefault and self.toolsArg is None and not movesProject and unsupported {
            self.pickedTools = selected;
            return False;
        }
        if unsupported and self.toolsKeyword() != "all" {
            one = len(unsupported) == 1;
            names = ", ".join([t.name for t in unsupported]);
            ids = ",".join([t.value for t in unsupported]);
            log(
                chalk().yellow(
                    f"{names} {'isn\'t' if one else 'aren\'t'} covered by the global skills. Where you use {'it' if one else 'them'}, run: openspec init --scope project --tools {ids}",
                ),
            );
        }
        if tools and not supported and (not installed.skills or self.toolsArg is not None) {
            raise fail(
                f"None of the selected tools are covered by the global skills, so nothing was set up. Run: openspec init --scope project --tools {','.join([t.value for t in tools])}",
            );
        }
        if movesProject {
            uncovered = [
                t.name
                for t in AI_TOOLS
                if t.value in configured
                    and usesSharedSkills(t)
                    and not supportsGlobalSkills(t.value)
            ];
            if uncovered {
                raise fail(
                    f"This project is set up for {', '.join(uncovered)}, which the global skills don't cover, so it keeps its own skills. Nothing was changed.",
                );
            }
            cloudIsOn = False;
            if self.copilotCloudOption is not False {
                optIn = readCopilotCloudOptIn(projectPath);
                cloudIsOn = truthy(optIn)
                    if not missing(optIn)
                    else await hasExistingManagedCloudFiles(projectPath);
            }
            if cloudIsOn {
                raise fail(
                    "This project has the GitHub Copilot cloud files set up, and that agent only sees skills kept in the project, so it keeps its own skills. Nothing was changed. To move it anyway and turn the cloud files off, add --no-copilot-cloud.",
                );
            }
            await self.removeProjectSkills(projectPath, True);
        }
        movedTools = [i for i in getConfiguredTools(projectPath) if supportsGlobalSkills(i)]
            if movesProject
            else [];
        migration = computeProfileMigration(projectPath, detectedTools)
            if movesProject and not self.resolveProfileOverride()
            else None;
        count: any = None;
        if installed.skills or supported or movedTools {
            result = await installGlobalSkills(
                rec(
                    toolIds=unique([*[t.value for t in supported], *movedTools]),
                    workflows=self.getActiveWorkflows()
                        if missing(migration)
                        else migration.workflows,
                    version=VERSION,
                ),
            );
            count = len(result.skills);
            removed = describeRemovedSkills(result.removedSkills);
            if removed {
                log(chalk().dim(removed));
            }
        }
        if movesProject {
            if not count {
                raise fail("No global skills were installed. This project keeps its skills.");
            }
            if not missing(migration) {
                migrateIfNeeded(projectPath, detectedTools);
            }
            if self.copilotCloudOption is False {
                await removeCopilotCloudFiles(
                    projectPath,
                    None,
                    lambda -> any { promise(persistCopilotCloudOptIn(projectPath, False, True)) },
                );
            }
            await self.removeProjectSkills(projectPath);
            log(
                "Commit the removed files. After pulling that commit, each teammate runs openspec update in a terminal and answers Yes to set up their tools, or runs openspec init --tools <ids> in a script.",
            );
        }
        if not integrationsOnly {
            await self.createDirectoryStructure(openspecPath, extendMode);
        }
        self.displaySuccessMessage(
            projectPath,
            rec(
                createdTools=supported,
                refreshedTools=[],
                failedTools=[],
                removedCommandCount=0,
                leftCommandFiles=rec(kept=[], unchecked=[]),
                removedSkillCount=0,
            ),
            "exists" if integrationsOnly else await self.createConfig(openspecPath),
            rec(write=False, skippedUndecided=False, present=[], collisions=[], removed=0),
            count,
        );
        return True;
    }

    async def removeProjectSkills(projectPath: str, checkOnly: bool = False) {
        configured = getConfiguredTools(projectPath);
        def input(ops: any, writes: bool) -> any {
            return rec(
                projectPath=projectPath,
                tools=[t for t in AI_TOOLS if t.value in configured],
                version=VERSION,
                workflowsFor=lambda (toolId: any) -> any { [] },
                view=DISK_VIEW,
                ops=ops,
                writesToDisk=writes,
            );
        }
        plan = await installSharedSkills(input(UpdatePlanRecorder(projectPath), False));
        for error in globalThis.Array.from(plan.toolFailures.values()) {
            raise error;
        }
        commands = [
            classifyCommandFiles(projectPath, i, [], DISK_VIEW, True)
            for i in configured
            if shouldReconcileCommandFilesForTool(i)
        ];
        kept = [
            FileSystemUtils.toPosixPath(p)
            for files in commands
            for p in [*files.kept, *files.unchecked]
        ];
        if kept {
            raise fail(
                f"These files have your own changes, so the project keeps its copy: {', '.join(kept)}. Nothing was removed. Delete them, or move your changes to a skill under another name, then run this again.",
            );
        }
        if checkOnly {
            return;
        }
        paths = unique([f.cmdPath for files in commands for f in files.generated]);
        for file in paths {
            await realFileOps.removeFile(
                FileSystemUtils.resolveProjectArtifactPath(projectPath, file), "openspec"
            );
        }
        await pruneEmptyParents(projectPath, [FileSystemUtils.toPosixPath(p) for p in paths]);
        cleanup = await installSharedSkills(input(realFileOps, True));
        for error in globalThis.Array.from(cleanup.toolFailures.values()) {
            raise error;
        }
        try {
            await forgetProjectSkills(projectPath);
        } except Exception {}
        log(chalk().dim("Removed this project's own OpenSpec skills"));
    }

    async def validate(projectPath: str, openspecPath: str) -> bool {
        extendMode = await FileSystemUtils.directoryExists(openspecPath);
        if not await FileSystemUtils.ensureWritePermissions(projectPath) {
            raise fail(f"Insufficient permissions to write to {projectPath}");
        }
        return extendMode;
    }

    def canPromptInteractively -> bool {
        if self.interactiveOption is False or self.toolsArg is not None {
            return False;
        }
        return isInteractive(rec(interactive=self.interactiveOption));
    }

    async def resolveCopilotCloudDecision(projectPath: str, tools: any) -> any {
        opt = self.copilotCloudOption;
        if "github-copilot" not in [t.value for t in tools] {
            if opt is not None {
                log(
                    chalk().yellow(
                        "--copilot-cloud/--no-copilot-cloud was ignored because the github-copilot tool was not selected.",
                    ),
                );
            }
            return rec(write=False, optedOut=False, skippedUndecided=False);
        }
        if opt is not None {
            return rec(write=opt, persist=opt, optedOut=not opt, skippedUndecided=False);
        }
        persisted = readCopilotCloudOptIn(projectPath);
        if kind(persisted) == "boolean" {
            return rec(write=persisted, optedOut=not persisted, skippedUndecided=False);
        }
        if await hasExistingManagedCloudFiles(projectPath) {
            return rec(write=True, optedOut=False, skippedUndecided=False);
        }
        if live(self).canPromptInteractively() {
            answer = await confirm(
                "Set up GitHub Copilot cloud coding-agent files? This is for the GitHub-hosted Copilot coding agent (github.com), not Copilot in your editor. It writes two files: .github/workflows/copilot-setup-steps.yml and .github/agents/openspec.agent.md.",
                False,
            );
            return rec(write=answer, persist=answer, optedOut=not answer, skippedUndecided=False);
        }
        return rec(write=False, optedOut=False, skippedUndecided=True);
    }

    def resolveProfileOverride -> any {
        p = self.profileOverride;
        if p is None or p in ["core", "custom"] {
            return p;
        }
        raise fail(f"Invalid profile \"{p}\". Available profiles: core, custom");
    }

    def getActiveWorkflows -> list[any] {
        cfg = getGlobalConfig();
        return [
            *getProfileWorkflows(
                self.resolveProfileOverride() ?? cfg["profile"] ?? "core", cfg["workflows"]
            ),
        ];
    }

    async def handleLegacyCleanup(projectPath: str) -> any {
        detection = await detectLegacyArtifacts(projectPath);
        if not detection.hasLegacyArtifacts {
            return None;
        }
        immediate = omitGlobalLegacyPromptFiles(detection);
        summary = formatDetectionSummary(immediate);
        if summary {
            log();
            log(summary);
            log();
        }
        deferredSummary = formatDeferredGlobalPromptSummary(detection);
        if deferredSummary {
            log(deferredSummary);
            log();
        }
        if not self.force
            and live(self).canPromptInteractively()
            and not await confirm("Upgrade and clean up legacy files?", True)
        {
            log(chalk().dim("Initialization cancelled."));
            log(
                chalk().dim(
                    "Run with --force to skip this prompt, or manually remove legacy files."
                ),
            );
            process.exit(0);
        }
        if immediate.hasLegacyArtifacts {
            await self.performLegacyCleanup(projectPath, immediate);
        }
        return detection if detection.globalSlashCommandFiles else None;
    }

    async def finalizeDeferredLegacyCleanup(projectPath: str, detection: any) {
        codex = findTool("codex");
        available = scanInstalledWorkflows(projectPath, [codex]) if codex else [];
        matches = getLegacyGlobalPromptMatches(detection);
        removable = [
            p.path
            for p in matches
            if not [w for w in p.workflowIds if w not in available]
        ];
        if removable {
            await self.performLegacyCleanup(
                projectPath, pickGlobalLegacyPromptFiles(detection, removable)
            );
        }
        blocked = [p for p in matches if p.path not in removable];
        if blocked {
            log(chalk().yellow("Preserved deferred global prompts without replacement skills:"));
            for p in blocked {
                log(chalk().dim(f"  - {p.toolId}: {p.path}"));
            }
            log();
        }
    }

    async def performLegacyCleanup(projectPath: str, detection: any) {
        spinner = pick("ora")("Cleaning up legacy files...").start();
        result = await cleanupLegacyArtifacts(projectPath, detection);
        spinner.succeed("Legacy files cleaned up");
        summary = formatCleanupSummary(result);
        if summary {
            log();
            log(summary);
        }
        log();
    }

    async def getSelectedTools(
        toolStates: any, extendMode: bool, detectedTools: any, projectPath: str
    ) -> any {
        if self.pickedTools is not None {
            return self.pickedTools;
        }
        explicit = self.resolveToolsArg();
        if explicit is not None {
            return explicit;
        }
        validTools = getToolsWithSkillsDir();
        detected = unique([t.value for t in detectedTools]);
        configuredIds = [t.value for t in AI_TOOLS if configuredIn(toolStates, t.value)];
        preselect = not extendMode and not configuredIds;
        if not live(self).canPromptInteractively() {
            if detected {
                return detected;
            }
            listing = "\n  ".join(validTools);
            hint = universalToolFallbackHint(validTools);
            raise fail(
                f"No tools detected and no --tools flag provided. Valid tools:\n  {listing}\n\nUse --tools all, --tools none, or --tools claude,cursor,...{f'\n{hint}' if hint else ''}",
            );
        }
        if not validTools {
            raise fail("No tools available for skill generation.");
        }
        detectAgents: any = merge(await load("skills")).detectAgents;
        machine = [a.id for a in (await detectAgents(rec(cwd=projectPath))).agents];
        for tool in AI_TOOLS {
            agent = installerAgent(tool.value);
            if agent.id != "universal" and agent.id in machine and tool.value not in detected {
                detected.append(tool.value);
            }
        }
        import from "../prompts/searchable-multi-select" { searchableMultiSelect }
        def choice(toolId: str) -> any {
            tool = findTool(toolId);
            configured = configuredIn(toolStates, toolId);
            isDetected = toolId in detected;
            return rec(
                name=at(tool, "name") or toolId,
                value=toolId,
                searchAliases=at(tool, "searchAliases"),
                configured=configured,
                detected=isDetected and not configured,
                preSelected=configured or (preselect and isDetected and not configured),
            );
        }
        choices = sorted(
            [choice(i) for i in validTools],
            key=lambda (c: any) -> int { 0 if c.configured else (1 if c.detected else 2) },
        );
        configuredNames = [at(findTool(i), "name") or i for i in validTools if i in configuredIds];
        if configuredNames {
            log(f"OpenSpec configured: {', '.join(configuredNames)} (pre-selected)");
        }
        detectedOnly = [t.name for t in detectedTools if t.value not in configuredIds];
        if detectedOnly {
            label = "pre-selected for first-time setup" if preselect else "not pre-selected";
            log(f"Detected tool directories: {', '.join(detectedOnly)} ({label})");
        }
        universal = getUniversalTool();
        selected = await searchableMultiSelect(
            rec(
                message=f"Select tools to set up ({len(validTools)} available)",
                pageSize=15,
                choices=choices,
                emptyHint=f"Tool not listed? Clear the search and pick \"{universal.name}\"."
                    if not missing(universal) and universal.value in validTools
                    else None,
                validate=lambda (picked: any) -> any {
                    True if len(picked) > 0 else "Select at least one tool"
                },
            ),
        );
        if len(selected) == 0 {
            raise fail("At least one tool must be selected");
        }
        return selected;
    }

    def resolveToolsArg -> any {
        if self.toolsArg is None {
            return None;
        }
        raw: any = self.toolsArg.trim();
        if len(raw) == 0 {
            raise fail(
                "The --tools option requires a value. Use \"all\", \"none\", or a comma-separated list of tool IDs.",
            );
        }
        available = getToolsWithSkillsDir();
        lower = raw.toLowerCase();
        if lower == "all" {
            return available;
        }
        if lower == "none" {
            return [];
        }
        tokens: list[any] = [t for t in [t.trim() for t in raw.split(",")] if len(t) > 0];
        if not tokens {
            raise fail(
                "The --tools option requires at least one tool ID when not using \"all\" or \"none\".",
            );
        }
        normalized = [resolveToolIdAlias(t.toLowerCase()) for t in tokens];
        if "all" in normalized or "none" in normalized {
            raise fail(
                "Cannot combine reserved values \"all\" or \"none\" with specific tool IDs."
            );
        }
        for token in normalized {
            retired = findRetiredTool(token);
            if retired is not None {
                raise fail(formatRetiredToolError(retired));
            }
        }
        invalid = [tokens[i] for i in range(len(tokens)) if normalized[i] not in available];
        if invalid {
            hint = universalToolFallbackHint(available);
            values = ", ".join(["all", "none", *available]);
            raise fail(
                f"Invalid tool(s): {', '.join(invalid)}. Available values: {values}{f'\n{hint}' if hint else ''}",
            );
        }
        return unique(normalized);
    }

    def validateTools(toolIds: any, toolStates: any) -> list[any] {
        selected: list[any] = [];
        for toolId in toolIds {
            tool = findTool(toolId);
            listing = "\n  ".join(getToolsWithSkillsDir());
            if not tool {
                raise fail(f"Unknown tool '{toolId}'. Valid tools:\n  {listing}");
            }
            if not toolSupportsSkills(tool) {
                raise fail(
                    f"Tool '{toolId}' does not support skill generation.\nTools with skill generation support:\n  {listing}",
                );
            }
            selected.append(tool);
        }
        return [
            rec(value=t.value, name=t.name, wasConfigured=configuredIn(toolStates, t.value))
            for t in selected
        ];
    }

    async def createDirectoryStructure(openspecPath: str, extendMode: bool) {
        spinner: any = None;
        if not extendMode {
            spinner = pick("ora")(
                rec(
                    text="Creating OpenSpec structure...",
                    stream=process.stdout,
                    color="gray",
                    spinner=PROGRESS_SPINNER,
                ),
            ).start();
        }
        base = path.dirname(openspecPath);
        for dir in [
            openspecPath,
            path.join(openspecPath, "specs"),
            path.join(openspecPath, "changes"),
            path.join(openspecPath, "changes", "archive"),
        ] {
            FileSystemUtils.assertProjectArtifactPath(base, dir);
            await FileSystemUtils.createDirectory(dir);
        }
        for relativeDir in ANCHORED_OPENSPEC_DIRS {
            await ensureDirectoryAnchor(base, relativeDir);
        }
        if spinner {
            spinner.stopAndPersist(
                rec(symbol=PALETTE.white("▌"), text=PALETTE.white("OpenSpec structure created"))
            );
        }
    }

    async def generateSkillsAndCommands(
        projectPath: str, tools: any, writeCopilotCloud: bool
    ) -> any {
        created: list[any] = [];
        refreshed: list[any] = [];
        failed: list[any] = [];
        kept: list[any] = [];
        unchecked: list[any] = [];
        removedCommandCount = 0;
        removedSkillCount = 0;
        workflows = profileWorkflows(self.resolveProfileOverride());
        async def reconcile(toolId: str) {
            r = await reconcileCommandFiles(projectPath, toolId, workflows);
            removedCommandCount += len(r.removed);
            kept.extend(r.kept);
            unchecked.extend(r.unchecked);
            await pruneEmptyParents(
                projectPath, [FileSystemUtils.toPosixPath(x) for x in r.removed]
            );
        }
        sharedIds = unique([*[t.value for t in tools], *getConfiguredTools(projectPath)])
            if tools
            else [];
        sharedTools = [t for t in AI_TOOLS if t.value in sharedIds];
        errors: any = {};
        try {
            shared = await installSharedSkills(
                rec(
                    projectPath=projectPath,
                    tools=sharedTools,
                    version=VERSION,
                    workflowsFor=lambda (toolId: any) -> any { workflows },
                    ops=realFileOps,
                    view=DISK_VIEW,
                    writesToDisk=True,
                ),
            );
            if shared.writtenSkillCount == 0 {
                removedSkillCount += shared.removedSkillCount;
            }
            errors = shared.toolFailures;
        } except Exception as e {
            failure = fail(
                f"the shared skills in .agents/skills could not be written: {errorMessage(e)}"
            );
            errors = {t.value: failure for t in sharedTools if usesSharedSkills(t)};
        }
        for retired in await cleanUpRetiredTools(
            projectPath,
            rec(view=DISK_VIEW, remove=lambda (p: str) -> any { fsp.unlink(p) }, prune=True),
        ) {
            printBlock(formatRetiredToolCleanup(retired, retired.tool.successor in sharedIds));
        }
        for tool in tools {
            spinner = pick("ora")(f"Setting up {tool.name}...").start();
            try {
                ownFolderError = errors.get(tool.value);
                if ownFolderError {
                    raise ownFolderError;
                }
                if shouldReconcileCommandFilesForTool(tool.value) {
                    await reconcile(tool.value);
                }
                if tool.value == "github-copilot" and writeCopilotCloud {
                    await writeCopilotCloudFiles(projectPath);
                }
                spinner.succeed(f"Setup complete for {tool.name}");
                (refreshed if tool.wasConfigured else created).append(tool);
            } except Exception as e {
                spinner.fail(f"Failed for {tool.name}");
                failed.append(rec(name=tool.name, error=js_error(e)));
            }
        }
        selectedIds = [t.value for t in tools];
        for other in [t for t in sharedTools if t.value not in selectedIds] {
            failure = errors.get(other.value);
            if failure {
                failed.append(rec(name=f"{other.name} (already set up here)", error=failure));
                continue;
            }
            if not shouldReconcileCommandFilesForTool(other.value) {
                continue;
            }
            try {
                await reconcile(other.value);
            } except Exception as e {
                failed.append(rec(name=other.name, error=js_error(e)));
            }
        }
        for tool in [*created, *refreshed] {
            reportMigrations(projectPath, [tool.value], "after-generation");
        }
        return rec(
            createdTools=created,
            refreshedTools=refreshed,
            failedTools=failed,
            removedCommandCount=removedCommandCount,
            leftCommandFiles=rec(kept=kept, unchecked=unchecked),
            removedSkillCount=removedSkillCount,
        );
    }

    def normalizeLanguage(language: any) -> any {
        if language is None {
            return None;
        }
        normalized: any = language.trim();
        if not normalized {
            raise fail("The --language option requires a non-empty value.");
        }
        if found(normalized, "\\p{Cc}|\\p{Bidi_Control}|[\\u200B\\u2028\\u2029\\uFEFF]", "u") {
            raise fail(
                "The --language option must be a single line without control or invisible formatting characters.",
            );
        }
        if globalThis.Buffer.byteLength(f"{formatLanguageContext(normalized)}\n", "utf8")
            > MAX_CONTEXT_SIZE
        {
            raise fail(
                f"The --language option is too long for OpenSpec's {globalThis.String(MAX_CONTEXT_SIZE / 1024)}KB project context limit.",
            );
        }
        return normalized;
    }

    def languageContext -> any {
        return formatLanguageContext(self.language) if self.language else None;
    }

    async def assertLanguageCanBeApplied(projectPath: str, openspecPath: str) {
        context = self.languageContext();
        if not context {
            return;
        }
        configPath = path.join(openspecPath, "config.yaml");
        if not existsSync(configPath) and not existsSync(path.join(openspecPath, "config.yml")) {
            try {
                FileSystemUtils.assertProjectArtifactPath(projectPath, configPath);
            } except Exception as e {
                raise fail(f"Cannot create openspec/config.yaml for --language{reason(e)}");
            }
            if not await FileSystemUtils.canWriteFile(configPath) {
                raise fail(
                    "Cannot create openspec/config.yaml for --language: the destination is not writable.",
                );
            }
            return;
        }
        existing = at(readProjectConfig(projectPath), "context");
        if existing and context in existing {
            return;
        }
        raise fail(
            "--language does not overwrite an existing OpenSpec config. Add the language instruction to its context field instead.",
        );
    }

    async def createConfig(openspecPath: str) -> str {
        configPath = path.join(openspecPath, "config.yaml");
        if existsSync(configPath) or existsSync(path.join(openspecPath, "config.yml")) {
            return "exists";
        }
        try {
            content = serializeConfig(rec(schema=DEFAULT_SCHEMA, context=self.languageContext()));
            FileSystemUtils.assertProjectArtifactPath(path.dirname(openspecPath), configPath);
            await FileSystemUtils.writeFile(configPath, content);
            return "created";
        } except Exception as e {
            if self.language {
                raise fail(f"Failed to create openspec/config.yaml for --language{reason(e)}");
            }
            return "skipped";
        }
    }

    def displaySuccessMessage(
        projectPath: str, results: any, configStatus: str, copilot: any, globalSkills: any = None
    ) {
        c = chalk();
        failed = results.failedTools;
        log();
        log(c.bold("OpenSpec Setup Incomplete" if failed else "OpenSpec Setup Complete"));
        log();
        if results.createdTools {
            log(f"Created: {', '.join([t.name for t in results.createdTools])}");
        }
        if results.refreshedTools {
            log(f"Refreshed: {', '.join([t.name for t in results.refreshedTools])}");
        }
        successful = [*results.createdTools, *results.refreshedTools];
        if globalSkills is not None {
            log(f"{globalSkills} skills in ~/.agents/skills/ for every project on this machine");
        } elif successful {
            folders = unique([
                f"{installerAgent(t.value).projectSkillsDir}/"
                for t in successful
                if SKILL_LINKED_TOOL_IDS.has(t.value)
            ]);
            locations = f" (also in {', '.join(folders)})" if folders else "";
            skills = getSkillTemplates(profileWorkflows(self.profileOverride));
            log(f"{len(skills)} skills in .agents/skills/{locations}");
        }
        if failed {
            log(c.red(f"Failed: {', '.join([f'{f.name} ({f.error.message})' for f in failed])}"));
        }
        n = results.removedCommandCount;
        if n > 0 {
            log(
                c.dim(
                    f"Removed: {n} command {'file' if n == 1 else 'files'} (OpenSpec 2.0 installs skills only)",
                ),
            );
        }
        for block in formatKeptCommandFiles(results.leftCommandFiles) {
            printBlock(block);
        }
        if results.removedSkillCount > 0 {
            log(c.dim(f"Removed: {results.removedSkillCount} skill directories"));
        }
        if "github-copilot" in [t.value for t in successful] {
            if copilot.write {
                if copilot.present {
                    log(f"GitHub Copilot cloud files: {', '.join(copilot.present)}");
                }
                if copilot.collisions {
                    log(
                        c.dim(
                            f"Left your existing {' and '.join(copilot.collisions)} untouched — add the OpenSpec install step by hand so the Copilot cloud agent can run openspec.",
                        ),
                    );
                }
            } elif copilot.removed > 0 {
                log(
                    c.dim(
                        f"Removed: {copilot.removed} Copilot cloud agent file(s) (opted out of cloud files)",
                    ),
                );
            } elif copilot.skippedUndecided {
                log(
                    c.dim(
                        "Skipped GitHub Copilot cloud files (opt-in). Enable with 'openspec init --copilot-cloud'.",
                    ),
                );
            }
        }
        for tool in successful {
            note = at(findTool(tool.value), "setupNote");
            if note and (globalSkills is None or installerAgent(tool.value).id == "universal") {
                log(c.yellow(f"Setup required for {tool.name}: {note}"));
            }
        }
        if configStatus == "created" {
            log(f"Config: openspec/config.yaml (schema: {DEFAULT_SCHEMA})");
        } elif configStatus == "exists" {
            dir = path.join(projectPath, OPENSPEC_DIR_NAME);
            name = "config.yml"
                if not existsSync(path.join(dir, "config.yaml"))
                    and existsSync(path.join(dir, "config.yml"))
                else "config.yaml";
            log(f"Config: openspec/{name} (exists)");
        } else {
            log(c.dim("Config: skipped (non-interactive mode)"));
        }
        active = self.getActiveWorkflows();
        delivery = getGlobalConfig()["delivery"] ?? "both";
        def startHints(command: str) {
            byHint: dict[str, list[str]] = {};
            for tool in successful {
                ref: any = getSkillReferenceTransformer(tool.value)(command);
                hint = f"Start your first change: {ref} \"your idea\"";
                if usesNaturalLanguageSkillReferences(tool.value) {
                    hint = f"Start your first change: ask {tool.name} to use {ref} with \"your idea\"";
                } elif tool.value == "codex" {
                    hint = f"Start your first change: {ref} \"your idea\" (Codex CLI or IDE); in the Codex desktop app, select {ref[1:]} from Skills in the sidebar";
                }
                byHint[hint] = [*byHint.get(hint, []), tool.name];
            }
            lines = [f"{h} ({', '.join(names)})" for (h, names) in byHint.items()]
                if len(byHint) > 1
                else list(byHint.keys());
            log(c.bold("Getting started:"));
            for line in lines or [
                f"Start your first change: {transformToSkillReferences(command)} \"your idea\"",
            ] {
                log(f"  {line}");
            }
        }
        log();
        if "propose" in active {
            startHints("/opsx:propose");
        } elif "new" in active {
            startHints("/opsx:new");
        } else {
            log("Done. Run 'openspec config profile' to configure your workflows.");
        }
        note = formatOptionalWorkflowsNote(active)
            if successful and ("propose" in active or "new" in active)
            else None;
        if note {
            log();
            for line in note {
                log(c.dim(line));
            }
        }
        log();
        log(f"Learn more: {c.cyan('https://github.com/Fission-AI/OpenSpec')}");
        log(f"Feedback:   {c.cyan('https://github.com/Fission-AI/OpenSpec/issues')}");
        restart = formatIdeRestart([t.value for t in successful], delivery);
        if restart {
            log();
            log(c.white(restart));
        }
        log();
    }
}

with entry {
    jsAsync(InitCommand, ["execute", "getSelectedTools"]);
}
