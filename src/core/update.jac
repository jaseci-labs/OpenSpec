import from "node:path" { default as path }
import from "node:process" { default as process }

glob:priv VERSION: str = packageJson().version,
          LEARN_MORE: str = "https://github.com/Fission-AI/OpenSpec";

def:priv chalk -> any {
    return pick("chalk");
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

def:priv noUpgrade -> any {
    return rec(
        newlyConfiguredTools=[], workflowOverrides=rec(), skippedSharedSkillTools=[], failedTools=[]
    );
}

glob:priv callOp: any = new(
    globalThis.Function, "o", "k", "a", "return Promise.resolve(o[k](...a))"
);

def:priv lookup(table: any, key: str) -> any {
    return table.get(key) if isinstance(table, globalThis.Map) else table[key];
}

def:priv noop(text: any = None) {}

async def:priv confirm(message: str, answer: bool) -> any {
    ask: any = merge(await load("@inquirer/prompts")).confirm;
    return await ask(globalThis.Object.fromEntries([["message", message], ["default", answer]]));
}

def scanInstalledWorkflows(projectPath: str, toolIds: any, view: any = None) -> list[any] {
    return migration.scanInstalledWorkflows(
        projectPath, [t for t in [findTool(i) for i in toolIds] if not missing(t)], view
    );
}

obj UpdateCommand(globalThis.Object) {
    def init(options: any = None) {
        super.init();
        self.force = at(options, "force") ?? False;
        self.dryRun = at(options, "dryRun") ?? False;
        self.editedGlobalPromptsReported = False;
        self.recorder = None;
        self.hasGlobalSkills = False;
        self.settledWorkflows = None;
        self.removedGlobalSkills = None;
        self.ops = realFileOps;
        self.legacyCleanupSkipped = False;
    }

    async def plan(projectPath: str) -> any {
        if not self.dryRun {
            raise fail("plan() requires the update command to be constructed with dryRun: true");
        }
        await self.execute(projectPath);
        return rec(changes=[], notes=[], failures=[])
            if self.recorder is None
            else self.recorder.getPlan();
    }

    def log(*args: any) {
        if not self.dryRun {
            globalThis.console.log(*args);
        }
    }

    def printBlock(lines: any) {
        self.log(chalk().yellow(lines[0]));
        for line in lines[1:] {
            self.log(chalk().dim(line));
        }
    }

    def startSpinner(text: str) -> any {
        if self.dryRun {
            return rec(succeed=noop, fail=noop, info=noop);
        }
        return pick("ora")(text).start();
    }

    def ensureRecorder(planRoot: str) -> any {
        if self.recorder is None {
            self.recorder = UpdatePlanRecorder(planRoot);
        }
        return self.recorder;
    }

    def currentView -> any {
        return DISK_VIEW if self.recorder is None else self.recorder.view;
    }

    def fileOps(tool: str) -> any {
        def writeFile(filePath: str, content: str, *rest: any) -> any {
            return callOp(self.ops, "writeFile", [filePath, content, tool]);
        }
        def removeFile(filePath: str, *rest: any) -> any {
            return callOp(self.ops, "removeFile", [filePath, tool]);
        }
        def removeEmptyDirectory(dirPath: str, *rest: any) -> any {
            return callOp(self.ops, "removeEmptyDirectory", [dirPath]);
        }
        return rec(
            writeFile=writeFile, removeFile=removeFile, removeEmptyDirectory=removeEmptyDirectory
        );
    }

    async def execute(projectPath: str) {
        resolved = path.resolve(projectPath);
        count = 0;
        try {
            count = len((await readGlobalSkills()).skills);
        } except Exception {}
        self.hasGlobalSkills = count > 0;
        if not self.dryRun {
            rememberProject(resolved);
        }
        self.settledWorkflows = None;
        self.removedGlobalSkills = None;
        hasProject = (await FileSystemUtils.directoryExists(path.join(resolved, OPENSPEC_DIR_NAME)))
            and not (self.hasGlobalSkills and isHomeFolder(resolved));
        if hasProject and not self.dryRun and isInteractive() and not self.force {
            prompts = merge(await load("@inquirer/prompts"));
            hasProjectSkills = projectHasOwnSkills(resolved);
            if hasProjectSkills and not keepsProjectSkills(resolved) {
                scope = await prompts.select(
                    globalThis.Object.fromEntries([
                        ["message", "Where should OpenSpec keep this project’s skills?"],
                        [
                            "choices",
                            [
                                rec(
                                    name="Keep in this project   Keep the skills in this repo.",
                                    value="project",
                                ),
                                rec(
                                    name="Switch to global       Install the skills globally, for every project on this machine.",
                                    value="global",
                                ),
                            ],
                        ],
                        ["default", "project"],
                    ]),
                );
                if scope == "project" {
                    saved: any = None;
                    try {
                        saved = await rememberProjectSkills(resolved);
                    } except Exception {}
                    globalThis.console.log(
                        f"Commit {FileSystemUtils.toPosixPath(path.relative(resolved, saved))} to keep this choice for the team."
                            if saved
                            else "Could not save this choice in openspec/config.yaml. Add \"skillsScope: project\" to it by hand to stop being asked.",
                    );
                } else {
                    cloud = await isCopilotCloudEnabled(resolved);
                    if not cloud
                        or await confirm(
                            "Turn off hosted Copilot for this repo to switch to global skills?",
                            False,
                        )
                    {
                        await InitCommand(
                            rec(
                                scope=scope,
                                tools=",".join(getConfiguredToolsForProfileSync(resolved)),
                                copilotCloud=False if cloud else None,
                            ),
                        ).execute(resolved);
                        return;
                    }
                }
            } elif not hasProjectSkills
                and not self.hasGlobalSkills
                and process.env["OPENSPEC_SKILLS_SCOPE"] != "project"
                and await confirm(
                    "Set up OpenSpec skills for your coding tools on this machine?", False
                )
            {
                await InitCommand(rec(scope="global")).execute(resolved);
                return;
            }
        }
        if not self.hasGlobalSkills {
            await self.updateProject(projectPath);
            return;
        }
        projectError: any = None;
        if hasProject {
            try {
                await self.updateProject(projectPath);
            } except Exception as e {
                projectError = js_error(e);
            }
        }
        try {
            refreshed = await self.refreshGlobalSkills(resolved);
            if self.dryRun and refreshed {
                recorder = self.ensureRecorder(resolved);
                recorder.addNote(
                    "global-skills",
                    "Update will also refresh the OpenSpec skills installed for this machine in ~/.agents/skills.",
                );
                if self.removedGlobalSkills {
                    recorder.addNote("removed-skills", self.removedGlobalSkills);
                }
            }
        } except Exception as e {
            err = js_error(e);
            if isinstance(projectError, globalThis.Error) and isinstance(err, globalThis.Error) {
                raise fail(f"{projectError.message}\n{err.message}");
            }
            raise err;
        }
        if not missing(projectError) {
            raise projectError;
        }
    }

    async def refreshGlobalSkills(planRoot: str) -> bool {
        c = chalk();
        cfg = getGlobalConfig();
        workflows = self.settledWorkflows ?? [
            w
            for w in withRouter(getProfileWorkflows(cfg["profile"] ?? "core", cfg["workflows"]))
            if w in SKILL_WORKFLOWS
        ];
        changed = False;
        try {
            result = await installGlobalSkills(
                rec(workflows=workflows, version=VERSION, force=self.force, dryRun=self.dryRun)
            );
            unchanged = truthy(result["unchanged"]);
            changed = not unchanged;
            n = len(result.skills);
            if unchanged {
                self.log(c.green(f"✓ The {n} skills for this machine are up to date (v{VERSION})"));
            } elif n > 0 {
                self.log(
                    c.green(
                        f"✓ Updated the {n} skills for this machine in ~/.agents/skills (v{VERSION})",
                    ),
                );
            } else {
                self.log(
                    c.yellow("Removed the skills for this machine: your profile has no workflows.")
                );
            }
            removed = describeRemovedSkills(result.removedSkills, not self.dryRun)
                if not unchanged and (self.dryRun or n > 0)
                else None;
            if removed and self.dryRun {
                self.removedGlobalSkills = removed;
            } elif removed {
                self.log(c.yellow(removed));
            }
        } except Exception as e {
            message = f"Could not update the skills for this machine: {describeSkillsError(js_error(e))}";
            if not self.dryRun {
                raise fail(message);
            }
            self.ensureRecorder(planRoot).addFailure("global-skills", message);
        }
        return changed;
    }

    def reportKeptInPlace(m: any) {
        notice = keptInPlaceNotice(m);
        if notice {
            self.log(chalk().dim(notice));
        }
    }

    def reportMigrations(migrations: any) {
        for m in migrations {
            if hasMovableContent(m) {
                self.log(
                    chalk().dim(f"Migrated {describeLegacyMigration(m)}: {m['from']} → {m.to}")
                );
            }
            self.reportKeptInPlace(m);
        }
    }

    async def afterGeneration(projectPath: str, toolId: str) {
        if self.dryRun {
            await self.planLegacyToolMoves(projectPath, "after-generation", [toolId]);
        } else {
            self.reportMigrations(
                migration.migrateLegacyToolDirs(projectPath, [toolId], "after-generation")
            );
        }
    }

    async def updateProject(projectPath: str) {
        c = chalk();
        resolved = path.resolve(projectPath);
        self.legacyCleanupSkipped = False;
        if self.dryRun {
            self.recorder = UpdatePlanRecorder(resolved);
            self.ops = self.recorder;
        }
        if not await FileSystemUtils.directoryExists(path.join(resolved, OPENSPEC_DIR_NAME)) {
            raise fail("No OpenSpec directory found. Run 'openspec init' first.");
        }
        declined: list[any] = [];
        if self.dryRun {
            await self.planLegacyToolMoves(resolved, "before-generation");
        } else {
            self.reportMigrations(migration.migrateLegacyToolDirs(resolved));
            declined = await self.offerConsentedLegacyMigrations(resolved);
        }
        view = self.currentView();
        detectedTools = getAvailableTools(resolved, view);
        if not self.dryRun {
            migration.migrateIfNeeded(resolved, detectedTools);
        }
        globalConfig = getGlobalConfig();
        if self.recorder is not None {
            planned = migration.computeProfileMigration(resolved, detectedTools, view);
            if not missing(planned) {
                globalConfig = migration.applyProfileMigration(planned);
                await self.recorder.writeFile(
                    getGlobalConfigPath(), serializeGlobalConfig(globalConfig), "openspec"
                );
            }
        }
        profile = globalConfig["profile"] ?? "core";
        delivery = globalConfig["delivery"] ?? "both";
        desired = [
            w
            for w in withRouter(getProfileWorkflows(profile, globalConfig["workflows"]))
            if w in SKILL_WORKFLOWS
        ];
        self.settledWorkflows = desired;
        legacy = await self.handleLegacyCleanup(resolved, desired);
        newly = legacy.newlyConfiguredTools;
        overrides = legacy.workflowOverrides;
        deferred = legacy["deferredGlobalCleanup"];
        legacyFailures = legacy.failedTools;
        def workflowsFor(toolId: any) -> any {
            return overrides[toolId] ?? desired;
        }
        for retired in await cleanUpRetiredTools(
            resolved,
            rec(
                view=view,
                remove=lambda (p: str) -> any { callOp(self.ops, "removeFile", [p, "openspec"]) },
                prune=not self.dryRun,
            ),
        ) {
            if retired.removed or self.force {
                self.printBlock(
                    formatRetiredToolCleanup(
                        retired,
                        retired.tool.successor in getConfiguredToolsForProfileSync(resolved, view),
                    ),
                );
            }
        }
        configured = getConfiguredToolsForProfileSync(resolved, view);
        configuredAndNew = unique([*configured, *newly]);
        if not configured and not newly {
            if deferred {
                await self.performDeferredGlobalPromptCleanup(resolved, deferred);
            }
            if self.stopIfUpdateFailed(legacyFailures) {
                return;
            }
            if declined {
                for m in declined {
                    self.log(
                        c.yellow(
                            f"Nothing to update: this project's OpenSpec files are still in {m['from']}/, which OpenSpec no longer writes.",
                        ),
                    );
                    self.log(
                        c.dim(
                            f"Re-run \"openspec update\" and accept the move to {m.to}/ to resume updates.",
                        ),
                    );
                }
                return;
            }
            await self.syncCopilotCloudFiles(resolved, configuredAndNew);
            if self.hasGlobalSkills {
                return;
            }
            self.log(c.yellow("No configured tools found."));
            self.log(c.dim("Run \"openspec init\" to set up tools."));
            return;
        }
        statuses = [
            getToolVersionStatus(
                resolved, toolId, VERSION, rec(workflows=workflowsFor(toolId), view=view)
            )
            for toolId in configured
        ];
        drifted = self.findToolsWithDriftedSkills(resolved, configured, workflowsFor);
        toUpdate = unique([
            *[s.toolId for s in statuses if s.needsUpdate],
            *getToolsNeedingProfileSync(resolved, desired, delivery, configured, view),
            *drifted,
        ]);
        upToDate = [s for s in statuses if s.toolId not in toUpdate];
        if not self.force and not toUpdate and not newly {
            if deferred {
                await self.performDeferredGlobalPromptCleanup(resolved, deferred);
            }
            await self.removeEarlierReleaseLeftovers(resolved, [], len(legacyFailures) > 0, False);
            self.log(c.green(f"✓ All {len(statuses)} tool(s) up to date (v{VERSION})"));
            self.log(c.dim(f"  Tools: {', '.join([s.toolId for s in statuses])}"));
            self.log();
            self.log(c.dim("Use --force to refresh files anyway."));
            await self.syncCopilotCloudFiles(resolved, configuredAndNew);
            self.displayNotes(resolved, configured, desired, profile);
            self.stopIfUpdateFailed(legacyFailures);
            return;
        }
        if self.force {
            self.log(f"Force updating {len(configured)} tool(s): {', '.join(configured)}");
        } elif not toUpdate {
            self.log("No additional refresh needed after legacy migration.");
        } else {
            self.displayUpdatePlan(toUpdate, statuses, upToDate, drifted);
        }
        self.log();
        targets = configured if self.force else toUpdate;
        updatedNames: list[any] = [];
        updatedIds: list[any] = [];
        failed: list[any] = [*legacyFailures];
        kept: list[any] = [];
        unchecked: list[any] = [];
        removedCommandCount = 0;
        removedSkillCount = 0;
        removedDeselected = 0;
        shared = await self.installSharedSkillsForRun(
            resolved, configuredAndNew, targets, workflowsFor
        );
        if shared.writtenSkillCount == 0 {
            removedSkillCount += shared.removedSkillCount;
        } else {
            removedDeselected += shared.removedSkillCount;
        }
        for toolId in targets {
            tool = findTool(toolId);
            if missing(tool) or not toolSupportsSkills(tool) {
                continue;
            }
            spinner = self.startSpinner(f"Updating {tool.name}...");
            try {
                ownFolderError = lookup(shared.toolFailures, tool.value);
                if ownFolderError {
                    raise ownFolderError;
                }
                if shouldReconcileCommandFilesForTool(tool.value) {
                    r = await reconcileCommandFiles(
                        resolved,
                        toolId,
                        workflowsFor(tool.value),
                        rec(
                            view=view,
                            remove=lambda (p: str) -> any {
                                callOp(self.ops, "removeFile", [p, toolId])
                            },
                        ),
                    );
                    removedCommandCount += len(r.removed);
                    kept.extend(r.kept);
                    unchecked.extend(r.unchecked);
                    if not self.dryRun {
                        await pruneEmptyParents(
                            resolved, [FileSystemUtils.toPosixPath(x) for x in r.removed]
                        );
                    }
                }
                spinner.succeed(f"Updated {tool.name}");
                updatedNames.append(tool.name);
                updatedIds.append(tool.value);
                await self.afterGeneration(resolved, tool.value);
            } except Exception as e {
                spinner.fail(f"Failed to update {tool.name}");
                message = errorMessage(e);
                failed.append(rec(name=tool.name, error=message));
                if self.recorder is not None {
                    self.recorder.addFailure(tool.value, message);
                }
            }
        }
        await self.removeEarlierReleaseLeftovers(resolved, updatedIds, len(failed) > 0);
        if deferred {
            await self.performDeferredGlobalPromptCleanup(resolved, deferred);
        }
        self.log();
        if updatedNames {
            self.log(c.green(f"✓ Updated: {', '.join(updatedNames)} (v{VERSION})"));
        }
        if failed {
            self.log(c.red(f"✗ Failed: {', '.join([f'{f.name} ({f.error})' for f in failed])}"));
        }
        if removedCommandCount > 0 {
            self.log(
                c.dim(
                    f"Removed: {removedCommandCount} command {'file' if removedCommandCount == 1 else 'files'} (OpenSpec 2.0 installs skills only)",
                ),
            );
        }
        for block in formatKeptCommandFiles(rec(kept=kept, unchecked=unchecked)) {
            self.printBlock(block);
        }
        if removedSkillCount > 0 {
            self.log(c.dim(f"Removed: {removedSkillCount} skill directories"));
        }
        if removedDeselected > 0 {
            self.log(
                c.dim(f"Removed: {removedDeselected} skill directories (deselected workflows)")
            );
        }
        if newly {
            def referenceFor(command: str) -> str {
                forms = unique([getSkillReferenceTransformer(i)(command) for i in newly]);
                neutral: any = transformToSkillReferences(command);
                return forms[0] if len(forms) == 1 else f"the {neutral.slice(1)} skill";
            }
            entries: list[tuple[any, any]] = [
                (referenceFor(e.command), e.description)
                for e in getOnboardingCommands(unique([w for i in newly for w in workflowsFor(i)]))
            ];
            self.log();
            if entries {
                width = max([len(ref) for (ref, _) in entries]);
                self.log(c.bold("Getting started:"));
                for (ref, description) in entries {
                    self.log(f"  {ref.padEnd(width)}  {description}");
                }
                self.log();
            }
            self.log(f"Learn more: {c.cyan(LEARN_MORE)}");
        }
        await self.syncCopilotCloudFiles(resolved, configuredAndNew);
        self.displayNotes(resolved, configuredAndNew, desired, profile);
        if updatedNames {
            self.log(c.dim(f"Tools: {', '.join(updatedNames)}"));
        }
        self.log();
        restart = formatIdeRestart(unique([*newly, *updatedIds]), delivery);
        if restart {
            self.log(c.dim(restart));
        }
        self.stopIfUpdateFailed(failed);
    }

    async def installSharedSkillsForRun(
        projectPath: str, setUpToolIds: any, toolsToRefresh: any, workflowsFor: any
    ) -> any {
        def options(ids: any) -> list[any] {
            return [t for t in [findTool(i) for i in ids] if not missing(t)];
        }
        if not [t for t in options(toolsToRefresh) if usesSharedSkills(t)] {
            return rec(writtenSkillCount=0, removedSkillCount=0, toolFailures=rec());
        }
        try {
            return await installSharedSkills(
                rec(
                    projectPath=projectPath,
                    tools=options(setUpToolIds),
                    version=VERSION,
                    workflowsFor=workflowsFor,
                    ops=self.ops,
                    view=self.currentView(),
                    writesToDisk=not self.dryRun,
                ),
            );
        } except Exception as e {
            message = errorMessage(e);
            self.log(
                chalk().red(f"✗ Could not write the shared skills in .agents/skills: {message}")
            );
            failure = fail(f"the shared skills in .agents/skills could not be written: {message}");
            return rec(
                writtenSkillCount=0,
                removedSkillCount=0,
                toolFailures=new(
                    globalThis.Map,
                    [[t.value, failure] for t in options(setUpToolIds) if usesSharedSkills(t)],
                ),
            );
        }
    }

    def stopIfUpdateFailed(failedTools: any) -> bool {
        if not self.dryRun and failedTools {
            raise fail(f"OpenSpec update failed for: {', '.join([t.name for t in failedTools])}");
        }
        return len(failedTools) > 0;
    }

    async def planLegacyToolMoves(projectPath: str, timing: str, toolIds: any = None) {
        recorder = self.recorder;
        if recorder is None {
            return;
        }
        for op in migration.planLegacyToolMigrations(projectPath, timing, toolIds, recorder.view) {
            try {
                if op.disposition == "move" {
                    await recorder.moveFile(op.source, op.destination, op.toolId);
                } else {
                    await recorder.removeFile(op.source, op.toolId);
                }
            } except Exception {
                continue;
            }
            if op.needsConsent {
                recorder.addNote(
                    "legacy-tool-directories",
                    "Moves out of a renamed tool directory are listed as a non-interactive update makes them. At a terminal, update asks first, and declining leaves those files where they are.",
                );
            }
        }
    }

    async def syncCopilotCloudFiles(projectPath: str, configuredTools: any) {
        c = chalk();
        ops = self.fileOps("github-copilot");
        try {
            if includesGitHubCopilot(configuredTools) {
                if await isCopilotCloudEnabled(projectPath) {
                    await writeCopilotCloudFiles(projectPath, ops);
                    collisions = await findUnmanagedCloudFiles(projectPath);
                    if collisions {
                        self.log(
                            c.dim(
                                f"Left your existing {' and '.join(collisions)} untouched — add the OpenSpec install step by hand so the Copilot cloud agent can run openspec.",
                            ),
                        );
                    }
                    return;
                }
                if readCopilotCloudOptIn(projectPath) is False {
                    removed = await removeCopilotCloudFiles(projectPath, ops);
                    if removed > 0 {
                        self.log(
                            c.dim(
                                f"Removed: {removed} Copilot cloud agent file(s) (opted out of cloud files)",
                            ),
                        );
                    }
                } elif isInteractive() {
                    self.log(
                        c.dim(
                            "GitHub Copilot cloud coding-agent files are available (opt-in). Enable with 'openspec init --copilot-cloud'.",
                        ),
                    );
                }
                return;
            }
            removed = await removeCopilotCloudFiles(projectPath, ops);
            if removed > 0 {
                self.log(
                    c.dim(
                        f"Removed: {removed} Copilot cloud agent file(s) (github-copilot not configured)",
                    ),
                );
            }
        } except Exception as e {
            globalThis.console.warn(
                f"Warning: failed to sync Copilot cloud agent files: {errorMessage(e)}"
            );
        }
    }

    def findToolsWithDriftedSkills(
        projectPath: str, toolIds: any, workflowsForTool: any
    ) -> list[any] {
        view = self.currentView();
        def drifted(toolId: str) -> bool {
            tool = findTool(toolId);
            if missing(tool)
                or not toolSupportsSkills(tool)
                or not truthy(at(getToolSkillStatus(projectPath, tool.value, view), "configured"))
                or (usesSharedSkills(tool) and not isToolListed(projectPath, tool.value, view))
            {
                return False;
            }
            linkDir = resolveSkillLinkDir(projectPath, tool);
            dirs = [resolveToolSkillsDir(projectPath, tool), *([linkDir] if linkDir else [])];
            skills = expectedSkillFiles(VERSION, workflowsForTool(toolId));
            for dir in dirs {
                for (name, files) in skills.entries() {
                    if not view.exists(path.join(dir, name, "SKILL.md")) {
                        continue;
                    }
                    for (file, generated) in files.entries() {
                        try {
                            expected = projectSkillText(toolId, generated)
                                if dir == linkDir and file == "SKILL.md"
                                else generated;
                            if normalizeGeneratedFile(view.read(path.join(dir, name, file)))
                                != expected
                            {
                                return True;
                            }
                        } except Exception {
                            return True;
                        }
                    }
                }
            }
            return False;
        }
        return [toolId for toolId in toolIds if drifted(toolId)];
    }

    async def removeEarlierReleaseLeftovers(
        projectPath: str, updatedToolIds: any, anyToolFailed: bool, reportKept: bool = True
    ) {
        stragglers = [
            e[0]
            for e in globalThis.Object.entries(migration.LEGACY_TOOL_ROOTS)
            if e[0] not in updatedToolIds and [r for r in e[1] if r["timing"] == "after-generation"]
        ];
        if stragglers and not anyToolFailed {
            if self.dryRun {
                await self.planLegacyToolMoves(projectPath, "after-generation", stragglers);
            } else {
                for m in migration.migrateLegacyToolDirs(
                    projectPath, stragglers, "after-generation"
                ) {
                    if hasMovableContent(m) {
                        self.log(
                            chalk().dim(
                                f"Removed old {describeLegacyMigration(m)} from {m['from']}"
                            ),
                        );
                    }
                    if reportKept {
                        self.reportKeptInPlace(m);
                    }
                }
            }
        }
        stale = []
            if self.legacyCleanupSkipped or anyToolFailed
            else await findStaleReleasedFiles(projectPath, self.currentView());
        removed: list[any] = [];
        for rel in stale {
            try {
                await callOp(
                    self.ops,
                    "removeFile",
                    [path.join(projectPath, *rel.split("/")), "earlier-release"],
                );
                removed.append(rel);
            } except Exception as e {
                self.log(chalk().yellow(f"Could not remove {rel}: {errorMessage(e)}"));
            }
        }
        if removed {
            if not self.dryRun {
                await pruneEmptyParents(projectPath, removed);
            }
            self.log(
                chalk().dim(
                    f"Removed {len(removed)} unchanged file{'' if len(removed) == 1 else 's'} an earlier OpenSpec release left where no tool reads them now.",
                ),
            );
        }
    }

    def displayUpdatePlan(toolsToUpdate: any, statuses: any, upToDate: any, drifted: any) {
        def describe(toolId: str) -> str {
            status: any = None;
            for s in statuses {
                if s.toolId == toolId {
                    status = s;
                }
            }
            if not missing(status)
                and status.needsUpdate
                and not (status.generatedByVersion is JsNull and toolId in drifted)
            {
                version = "unknown"
                    if missing(status.generatedByVersion)
                    else status.generatedByVersion;
                return f"{status.toolId} ({version} → {VERSION})";
            }
            if toolId in drifted {
                return f"{toolId} (skill files differ from the generated content)";
            }
            return f"{toolId} (config sync)";
        }
        self.log(
            f"Updating {len(toolsToUpdate)} tool(s): {', '.join([describe(i) for i in toolsToUpdate])}",
        );
        if upToDate {
            self.log(chalk().dim(f"Already up to date: {', '.join([s.toolId for s in upToDate])}"));
        }
    }

    def displayNotes(projectPath: str, configuredTools: any, workflows: any, profile: str) {
        c = chalk();
        if not (self.hasGlobalSkills and not configuredTools) {
            names = [
                t.name
                for t in getAvailableTools(projectPath)
                if t.value not in configuredTools
            ];
            if names {
                one = len(names) == 1;
                self.log();
                self.log(
                    c.yellow(
                        f"Detected new {'tool' if one else 'tools'}: {', '.join(names)}. Run 'openspec init' to add {'it' if one else 'them'}.",
                    ),
                );
            }
        }
        extra = [
            w
            for w in scanInstalledWorkflows(projectPath, configuredTools)
            if w not in workflows
        ];
        if extra {
            self.log(
                c.dim(
                    f"Note: {len(extra)} extra {'workflow' if len(extra) == 1 else 'workflows'} not in profile (use `openspec config profile` to manage)",
                ),
            );
        }
        missingCore = [w for w in CORE_WORKFLOWS if w not in workflows]
            if profile == "custom"
            else [];
        if missingCore {
            one = len(missingCore) == 1;
            self.log(
                c.dim(
                    f"Note: Your custom profile is missing {len(missingCore)} core {'workflow' if one else 'workflows'}: {', '.join(missingCore)}",
                ),
            );
            self.log(
                c.dim(
                    f"Run `openspec config profile` to add {'it' if one else 'them'}, or `openspec config profile core` to use the core set.",
                ),
            );
        }
        note = formatOptionalWorkflowsNote(workflows)
            if configuredTools and not extra and not missingCore
            else None;
        for line in note or [] {
            self.log(c.dim(line));
        }
        for toolId in configuredTools {
            setupNote = at(findTool(toolId), "setupNote");
            if setupNote {
                self.log(c.yellow(f"Setup required for {findTool(toolId).name}: {setupNote}"));
            }
        }
    }

    async def offerConsentedLegacyMigrations(projectPath: str) -> list[any] {
        c = chalk();
        declined: list[any] = [];
        for m in migration.findLegacyToolMigrations(projectPath) {
            if not m.needsConsent {
                continue;
            }
            if not hasMovableContent(m) {
                self.reportKeptInPlace(m);
                self.log();
                continue;
            }
            self.log(c.yellow(legacyMigrationNotice(m)));
            if not self.force and isInteractive() {
                accepted: any = False;
                try {
                    accepted = await confirm(
                        f"Move {describeLegacyMigration(m)} from {m['from']}/ to {m.to}/?", True
                    );
                } except Exception {
                    accepted = False;
                }
                if not accepted {
                    self.log(
                        c.dim(
                            f"Left in place. OpenSpec writes {m.to}/ now and will not manage {m['from']}/, so those files stay as they are until you move them. You will be asked again next run.",
                        ),
                    );
                    self.log();
                    declined.append(m);
                    continue;
                }
            }
            self.reportMigrations(migration.migrateLegacyToolDirs(projectPath, [m.toolId]));
            self.log();
        }
        return declined;
    }

    async def handleLegacyCleanup(projectPath: str, desiredWorkflows: any) -> any {
        c = chalk();
        detection = await detectLegacyArtifacts(projectPath);
        if self.force {
            await self.reportEditedGlobalPrompts();
        }
        if not detection.hasLegacyArtifacts {
            return noUpgrade();
        }
        projectDetection = omitGlobalLegacyPromptFiles(detection);
        immediateSummary = formatDetectionSummary(projectDetection);
        deferredSummary = formatDeferredGlobalPromptSummary(detection);
        if immediateSummary or deferredSummary {
            self.log();
            for summary in [immediateSummary, deferredSummary] {
                if summary {
                    self.log(summary);
                    self.log();
                }
            }
        }
        canPrompt = not self.dryRun and isInteractive();
        hasProjectRemovals = hasRepoLocalLegacyRemovals(detection);
        globalPrompts = len(detection.globalSlashCommandFiles);
        onlyReleased = not self.force
            and hasProjectRemovals
            and not (canPrompt and globalPrompts > 0)
            and await legacyCleanupDeletesOnlyReleasedOutput(projectPath, detection);
        if onlyReleased {
            self.log(
                c.dim(
                    "These are unchanged files from an earlier OpenSpec release, so update removes them.",
                ),
            );
            self.log();
        }
        if not (self.force or onlyReleased) {
            if not canPrompt {
                self.legacyCleanupSkipped = hasProjectRemovals;
                self.log(
                    c.yellow(
                        "⚠ Run with --force to auto-cleanup legacy files, or run interactively."
                    ),
                );
                self.log();
                if self.recorder is not None {
                    self.recorder.addNote(
                        "legacy-artifacts",
                        "Legacy OpenSpec artifacts were found. Update cleans them up only with --force or when you confirm at a terminal, so this plan leaves them alone; --dry-run --force lists that cleanup.",
                    );
                }
                return noUpgrade();
            }
            if not await confirm("Upgrade and clean up legacy files?", True) {
                self.legacyCleanupSkipped = hasProjectRemovals;
                self.log(c.dim("Skipping legacy cleanup. Continuing with skill update..."));
                self.log();
                return noUpgrade();
            }
        }
        upgrade = await self.upgradeLegacyTools(
            projectPath,
            projectDetection if onlyReleased else detection,
            canPrompt and not onlyReleased,
            desiredWorkflows,
        );
        if onlyReleased and upgrade.failedTools {
            self.legacyCleanupSkipped = True;
            self.log(
                c.yellow(
                    "⚠ Kept the earlier release files because a tool failed to set up. Fix it and run update again.",
                ),
            );
            return upgrade;
        }
        without = [
            *upgrade.skippedSharedSkillTools,
            *[f.toolId for f in upgrade.failedTools if f["toolId"]],
        ];
        immediate = omitToolLegacyArtifacts(projectDetection, without);
        if immediate.hasLegacyArtifacts {
            await self.performLegacyCleanup(projectPath, immediate);
        }
        if onlyReleased and globalPrompts > 0 {
            self.log(
                c.dim(
                    f"Left {globalPrompts} OpenSpec prompt file(s) in your home folder: other projects may still use them. Run \"openspec update --force\" to remove them.",
                ),
            );
            return upgrade;
        }
        upgrade.deferredGlobalCleanup = pickGlobalLegacyPromptFiles(
            detection, detection.globalSlashCommandFiles
        );
        return upgrade;
    }

    async def performDeferredGlobalPromptCleanup(projectPath: str, detection: any) {
        available = scanInstalledWorkflows(projectPath, ["codex"], self.currentView());
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
            await self.reportEditedGlobalPrompts();
        }
        blocked = [p for p in matches if p.path not in removable];
        if blocked {
            self.log(
                chalk().yellow("Preserved deferred global prompts without replacement skills:")
            );
            for p in blocked {
                self.log(chalk().dim(f"  - {p.toolId}: {p.path}"));
            }
            self.log();
        }
    }

    async def reportEditedGlobalPrompts {
        if self.editedGlobalPromptsReported {
            return;
        }
        self.editedGlobalPromptsReported = True;
        edited = await findEditedLegacyGlobalPrompts();
        if not edited {
            return;
        }
        one = len(edited) == 1;
        self.log(
            chalk().yellow(
                f"Kept {len(edited)} prompt {'file' if one else 'files'} in your home folder that {'differs' if one else 'differ'} from what OpenSpec generated (likely edited):",
            ),
        );
        for file in edited {
            self.log(chalk().dim(f"  {file}"));
        }
        self.log(chalk().dim("Move anything worth keeping into the skill, then delete by hand."));
        self.log();
    }

    async def performLegacyCleanup(projectPath: str, detection: any) {
        spinner = self.startSpinner("Cleaning up legacy files...");
        result = await cleanupLegacyArtifacts(projectPath, detection, self.fileOps("openspec"));
        spinner.succeed("Legacy files cleaned up");
        summary = formatCleanupSummary(result);
        if summary {
            self.log();
            self.log(summary);
        }
        self.log();
    }

    async def upgradeLegacyTools(
        projectPath: str, detection: any, canPrompt: bool, desiredWorkflows: any
    ) -> any {
        c = chalk();
        configured = getConfiguredToolsForProfileSync(projectPath, self.currentView());
        valid = getToolsWithSkillsDir();
        candidates = [
            t
            for t in getToolsFromLegacyArtifacts(detection)
            if t not in configured and t in valid
        ];
        if not candidates {
            return noUpgrade();
        }
        self.log(c.bold("Tools detected from legacy artifacts:"));
        for toolId in candidates {
            self.log(f"  • {at(findTool(toolId), 'name') or toolId}");
        }
        self.log();
        selected: any = candidates;
        if self.force or not canPrompt {
            self.log(f"Setting up skills for: {', '.join(selected)}");
        } else {
            selected = await searchableMultiSelect(
                rec(
                    message="Select tools to set up with the new skill system:",
                    pageSize=15,
                    choices=[
                        rec(
                            name=at(findTool(i), "name") or i,
                            value=i,
                            searchAliases=at(findTool(i), "searchAliases"),
                            configured=False,
                            preSelected=True,
                        )
                        for i in candidates
                    ],
                    validate=lambda (picked: any) -> any { True },
                ),
            );
            if len(selected) == 0 {
                self.log(c.dim("Skipping tool setup."));
                self.log();
                return noUpgrade();
            }
        }
        inferred = [
            w
            for w in withRouter(
                getProfileWorkflows("custom", getLegacyWorkflowIdsForTool(detection, "codex"))
            )
            if w in SKILL_WORKFLOWS
        ];
        def workflowsFor(toolId: any) -> any {
            return inferred if toolId == "codex" and inferred else desiredWorkflows;
        }
        newly: list[any] = [];
        failed: list[any] = [];
        overrides = rec();
        shared = await self.installSharedSkillsForRun(
            projectPath, unique([*configured, *selected]), selected, workflowsFor
        );
        for toolId in selected {
            tool = findTool(toolId);
            if missing(tool) or not toolSupportsSkills(tool) {
                continue;
            }
            spinner = self.startSpinner(f"Setting up {tool.name}...");
            try {
                ownFolderError = lookup(shared.toolFailures, tool.value);
                if ownFolderError {
                    raise ownFolderError;
                }
                if tool.value == "codex" and inferred {
                    overrides[tool.value] = inferred;
                }
                spinner.succeed(f"Setup complete for {tool.name}");
                newly.append(toolId);
                await self.afterGeneration(projectPath, tool.value);
            } except Exception as e {
                spinner.fail(f"Failed to set up {tool.name}");
                message = errorMessage(e);
                self.log(c.red(f"  {message}"));
                failed.append(rec(name=tool.name, error=message, toolId=tool.value));
                if self.recorder is not None {
                    self.recorder.addFailure(tool.value, message);
                }
            }
        }
        if newly {
            self.log();
        }
        return rec(
            newlyConfiguredTools=newly,
            workflowOverrides=overrides,
            skippedSharedSkillTools=[],
            failedTools=failed,
        );
    }
}

with entry {
    jsAsync(UpdateCommand, ["plan", "execute"]);
}
