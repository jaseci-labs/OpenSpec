import from "node:process" { default as process }
import from "node:path" { join, resolve }
import from "node:fs" { existsSync }
import from "node:fs/promises" { stat }

glob:priv version: str = packageJson().version,
          HIDDEN: str = "hidden",
          STORE: list[any] = [
              ("--store <id>", COMMON_FLAGS.store.description),
              (
                  "--store-path <path>",
                  "Not supported; register the path with \"openspec store register <path>\" and use --store <id>",
                  HIDDEN,
              ),
          ];

def:priv message(error: any) -> any {
    return globalThis.String(at(error, "message"));
}

async def:priv failWithError(error: any, json: any = None) {
    if at(json, "enabled") {
        import from "../commands/shared-output" { asStatus, printJson }
        printJson(
            merge(
                at(json, "payload") ?? rec(),
                rec(status=[asStatus(error, at(json, "fallbackCode") ?? "command_error")]),
            ),
        );
        process.exitCode = 1;
        return;
    }
    (await load("ora")).default().fail(f"Error: {message(error)}");
    fix = at(error, "diagnostic", "fix");
    if fix {
        globalThis.console.error(f"Fix: {fix}");
    }
    process.exitCode = process.exitCode ?? 1;
}

def:priv crash(fallbackCode: any = None, payload: any = None, exits: bool = True) -> any {
    async def fail(error: any, options: any) {
        await failWithError(
            error,
            rec(
                enabled=options["json"],
                payload=payload(options) if payload else None,
                fallbackCode=fallbackCode,
            )
                if fallbackCode
                else None,
        );
        if exits {
            process.exit(1);
        }
    }
    return fail;
}

async def:priv reportError(error: any, options: any) {
    globalThis.console.error(f"Error: {message(error)}");
    process.exitCode = 1;
}

def getCommandPath(command: any) -> str {
    names: list[str] = [];
    current = command;
    while current {
        name = current.name();
        if name and name != "openspec" {
            names.insert(0, name);
        }
        current = current.parent;
    }
    return ":".join(names) or "openspec";
}

def isJsonRun(command: any) -> bool {
    return same(command.optsWithGlobals()["json"], True) or "--json" in command.args;
}

def isCompletionRun(commandPath: str) -> bool {
    return commandPath.split(":")[0] == "completion" or commandPath == "__complete";
}

def isTabCompletionRun(commandPath: str) -> bool {
    return commandPath == "__complete";
}

def shouldDeferCompletionTip(command: any, stderrIsTty: bool) -> bool {
    return isJsonRun(command) or isCompletionRun(getCommandPath(command)) or not stderrIsTty;
}

async def:priv beforeAction(thisCommand: any, actionCommand: any) {
    if same(thisCommand.opts()["color"], False) {
        process.env.NO_COLOR = "1";
    }
    commandPath = getCommandPath(actionCommand);
    if isTabCompletionRun(commandPath) {
        return;
    }
    import from src.telemetry.index { maybeShowTelemetryNotice, trackCommand }
    await maybeShowTelemetryNotice(rec(silent=isJsonRun(actionCommand)));
    await trackCommand(commandPath, version);
}

async def:priv afterAction(thisCommand: any, actionCommand: any) {
    if isTabCompletionRun(getCommandPath(actionCommand)) {
        return;
    }
    import from "../core/completion-tip" { maybeShowCompletionTip }
    import from src.telemetry.index { shutdown }
    try {
        await maybeShowCompletionTip(
            rec(
                silent=shouldDeferCompletionTip(
                    actionCommand, globalThis.Boolean(process.stderr["isTTY"])
                ),
            ),
        );
    } finally {
        await shutdown();
    }
}

def:priv initToolsHelp -> str {
    import from src.core.config { AI_TOOLS, TOOL_ID_ALIASES }
    ids = ", ".join([t.value for t in AI_TOOLS]);
    aliases = ", ".join([
        f"{p[0]} (now {p[1]})"
        for p in globalThis.Object.entries(TOOL_ID_ALIASES)
    ]);
    return f"\nUse \"all\", \"none\", or a comma-separated list of: {ids}. Also accepted: {aliases}.";
}

async def:priv showVersion(arg: any, options: any) {
    import from "../core/version-check" {
        buildVersionReportLines,
        canSelfUpgrade,
        checkForCliUpdate,
        getCliInstallInfo,
        getCliUpdateCommand,
    }
    install = getCliInstallInfo();
    update: any = None;
    if options["check"] {
        update = await checkForCliUpdate(rec(requested=True));
    }
    command = getCliUpdateCommand(install) if at(update, "status") == "available" else JsNull;
    output = rec(schemaVersion=1, version=version, install=install);
    if update {
        output.update = merge(
            update,
            rec(
                command=command,
                canSelfUpgrade=canSelfUpgrade(install.location, process.cwd())
                    if update.status == "available"
                    else False,
            ),
        );
    }
    if options["json"] {
        globalThis.console.log(globalThis.JSON.stringify(output, None, 2));
        return;
    }
    globalThis.console.log("\n".join(buildVersionReportLines(version, install, update, command)));
}

async def:priv runInit(targetPath: any, options: any) {
    import from src.core.init { InitCommand }
    target = targetPath ?? ".";
    try {
        if not (await stat(resolve(target))).isDirectory() {
            raise new(globalThis.Error, f"Path \"{target}\" is not a directory");
        }
    } except Exception as e {
        error = js_error(e);
        if at(error, "code") == "ENOENT" {
            globalThis.console.log(f"Directory \"{target}\" doesn't exist, it will be created.");
        } elif at(error, "message") and "not a directory" in error.message {
            raise error;
        } else {
            raise new(globalThis.Error, f"Cannot access path \"{target}\": {message(error)}");
        }
    }
    await InitCommand(
        rec(
            tools=options["tools"],
            language=options["language"],
            force=options["force"],
            profile=options["profile"],
            animation=options["animation"],
            copilotCloud=options["copilotCloud"],
            scope=options["scope"],
        ),
    ).execute(target);
}

async def:priv runExperimental(arg: any, options: any) {
    import from src.core.init { InitCommand }
    globalThis.console.log(
        "Note: \"openspec experimental\" is deprecated. Use \"openspec init\" instead."
    );
    await InitCommand(
        rec(
            tools=options["tool"],
            interactive=False if same(options["noInteractive"], True) else None,
        ),
    ).execute(".");
}

async def:priv runUpdate(targetPath: any, options: any) {
    import from src.core.update { UpdateCommand }
    import from "../core/update-plan" { formatUpdatePlan }
    import from "../core/version-check" {
        displayCliUpdateNote,
        displayUpgradeCommand,
        getAvailableCliUpdate,
        getInstallDir,
        isSourceCheckout,
        offerCliUpgrade,
        rerunUpdateWithUpgradedCli,
        shouldOfferUpgrade,
    }
    import from src.utils.interactive { isInteractive }
    import from "../core/standalone-tip" { maybeShowStandaloneTip }
    target = targetPath ?? ".";
    if options["json"] and not options["dryRun"] {
        globalThis.console.error("--json is only available with --dry-run.");
        process.exitCode = 1;
        return;
    }
    if options["dryRun"] {
        plan = await UpdateCommand(rec(force=options["force"], dryRun=True)).plan(target);
        globalThis.console.log(
            globalThis.JSON.stringify(plan, None, 2) if options["json"] else formatUpdatePlan(plan)
        );
        return;
    }
    installDir = getInstallDir();
    latestVersion: any = JsNull;
    if not isSourceCheckout(installDir) {
        latestVersion = await getAvailableCliUpdate();
    }
    canOffer = not same(latestVersion, JsNull)
        and shouldOfferUpgrade(
            rec(
                installDir=installDir,
                projectPath=target,
                interactive=isInteractive(),
                stdoutIsTty=globalThis.Boolean(process.stdout["isTTY"]),
            ),
        );
    declined = False;
    if latestVersion and canOffer {
        displayCliUpdateNote(latestVersion, target, rec(withCommand=False));
        outcome = await offerCliUpgrade(latestVersion);
        if outcome == "cancelled" {
            process.exitCode = 130;
            return;
        }
        if outcome == "upgraded" {
            process.exitCode = await rerunUpdateWithUpgradedCli(
                target, rec(force=options["force"])
            );
            return;
        }
        declined = True;
    }
    await UpdateCommand(rec(force=options["force"])).execute(target);
    if declined {
        displayUpgradeCommand(target);
    } elif latestVersion {
        displayCliUpdateNote(latestVersion, target);
    }
    await maybeShowStandaloneTip(rec(silent=not process.stderr["isTTY"]));
}

async def:priv runInstall(requested: any, options: any) {
    import from "../commands/install-standalone" { installStandalone }
    await installStandalone(rec(version=requested));
}

def:priv listPayload(options: any) -> any {
    return rec(specs=[], root=JsNull) if options["specs"] else rec(changes=[], root=JsNull);
}

async def:priv runList(arg: any, options: any) {
    import from "../core/root-selection" { resolveRootForCommand, toRootOutput }
    import from src.core.list { ListCommand }
    if options["specs"] and (options["archived"] or options["all"]) {
        raise new(globalThis.Error, "--archived and --all can only be used when listing changes.");
    }
    selected = await resolveRootForCommand(
        options,
        rec(
            json=options["json"],
            failurePayload=listPayload(options),
            allowImplicitRoot=existsSync(join(process.cwd(), "openspec", "project.md")),
        ),
    );
    if not selected {
        return;
    }
    listOptions = rec(
        sort="name" if options["sort"] == "name" else "recent",
        json=options["json"],
        archived=options["archived"],
        all=options["all"],
    );
    if options["json"] {
        listOptions["root"] = toRootOutput(selected);
    }
    await ListCommand().execute(
        selected.path, "specs" if options["specs"] else "changes", listOptions
    );
}

async def:priv runView(arg: any, options: any) {
    import from "../core/root-selection" { resolveRootForCommand }
    import from src.core.view { ViewCommand }
    selected = await resolveRootForCommand(options);
    if selected {
        await ViewCommand().execute(selected.path);
    }
}

async def:priv changeShow(changeName: any, options: any) {
    import from src.commands.change { ChangeCommand }
    await ChangeCommand().show(changeName, options);
}

async def:priv changeList(arg: any, options: any) {
    import from src.commands.change { ChangeCommand }
    globalThis.console.error(
        "Warning: \"openspec change list\" is deprecated. Use \"openspec list\"."
    );
    await ChangeCommand().listChanges(options);
}

async def:priv changeValidate(changeName: any, options: any) {
    import from src.commands.change { ChangeCommand }
    await ChangeCommand().validate(changeName, options);
}

async def:priv runArchive(changeName: any, options: any) {
    import from src.core.archive { ArchiveCommand }
    await ArchiveCommand().execute(changeName, options);
}

async def:priv runValidate(itemName: any, options: any) {
    import from src.commands.validate { ValidateCommand }
    await ValidateCommand().execute(itemName, options);
}

async def:priv runShow(itemName: any, options: any) {
    import from src.commands.show { ShowCommand }
    await ShowCommand().execute(itemName, options);
}

async def:priv runFeedback(text: any, options: any) {
    import from src.commands.feedback { FeedbackCommand }
    await FeedbackCommand().execute(text, options);
}

async def:priv completionGenerate(shell: any, options: any) {
    import from src.commands.completion { CompletionCommand }
    await CompletionCommand().generate(rec(shell=shell));
}

async def:priv completionInstall(shell: any, options: any) {
    import from src.commands.completion { CompletionCommand }
    await CompletionCommand().install(rec(shell=shell, verbose=options["verbose"]));
}

async def:priv completionUninstall(shell: any, options: any) {
    import from src.commands.completion { CompletionCommand }
    await CompletionCommand().uninstall(rec(shell=shell, yes=options["yes"]));
}

async def:priv complete(completionType: any, options: any) {
    import from src.commands.completion { CompletionCommand }
    await CompletionCommand().complete(rec(type=completionType));
}

async def:priv completeFailed(error: any, options: any) {
    process.exitCode = 1;
}

async def:priv runStatus(arg: any, options: any) {
    import from src.commands.workflow.status { statusCommand }
    await statusCommand(options);
}

def:priv statusPayload(options: any) -> any {
    import from src.commands.workflow.status { BATCH_STATUS_FAILURE_PAYLOAD }
    return BATCH_STATUS_FAILURE_PAYLOAD if options["all"] else None;
}

async def:priv runInstructions(artifactId: any, options: any) {
    import from src.commands.workflow.instructions {
        applyInstructionsCommand,
        archiveInstructionsCommand,
        instructionsCommand,
    }
    if artifactId == "apply" {
        await applyInstructionsCommand(options);
    } elif artifactId == "archive" {
        await archiveInstructionsCommand(options);
    } else {
        await instructionsCommand(artifactId, options);
    }
}

async def:priv runTemplates(arg: any, options: any) {
    import from src.commands.workflow.templates { templatesCommand }
    await templatesCommand(options);
}

async def:priv runSchemas(arg: any, options: any) {
    import from src.commands.workflow.schemas { schemasCommand }
    await schemasCommand(options);
}

async def:priv runNewChange(name: any, options: any) {
    import from "../commands/workflow/new-change" { newChangeCommand }
    await newChangeCommand(name, options);
}

def:priv deprecatedChange {
    globalThis.console.error(
        "Warning: The \"openspec change ...\" commands are deprecated. Prefer verb-first commands (e.g., \"openspec list\", \"openspec validate --changes\").",
    );
}

def:priv define(
    parent: any, usage: str, description: str, options: list[any], run: any, failure: any
) {
    name = usage.split()[0];
    cmd = parent.command(
        usage, rec(hidden=True) if name in ["experimental", "__complete"] else None
    ).description(description);
    for option in options {
        made = cmd.createOption(option[0], option[1]);
        if len(option) > 2 {
            if option[2] == HIDDEN {
                made.hideHelp();
            } else {
                made.default(option[2]);
            }
        }
        cmd.addOption(made);
    }
    if name == "init" {
        cmd.addHelpText("after", initToolsHelp);
    } elif name == "show" and parent.name() == "openspec" {
        cmd.allowUnknownOption(True);
    }
    positional = len(cmd.registeredArguments) > 0;
    async def action(first: any, second: any) {
        (arg, opts) = (first, second) if positional else (None, first);
        if failure is None {
            await run(arg, opts);
            return;
        }
        try {
            await run(arg, opts);
        } except Exception as e {
            await failure(js_error(e), opts);
        }
    }
    cmd.action(action);
}

def:priv build -> any {
    root_ = new(pick("commander", "Command"));
    root_.name("openspec").description("AI-native system for spec-driven development").version(
        version
    );
    root_.option("--no-color", "Disable color output");
    json = ("--json", "Output as JSON");
    schema = ("--schema <name>", "Schema override (auto-detected from config.yaml)");
    noInteractive = ("--no-interactive", "Disable interactive prompts");
    groups = {
        "change": "Manage OpenSpec change proposals",
        "completion": "Manage shell completions for OpenSpec CLI",
        "new": "Create new items",
    };
    leading: list[any] = [
        (
            "version",
            "Report the installed OpenSpec version and update availability",
            [json, ("--check", "Check the registry for a newer version")],
            showVersion,
            None,
        ),
        (
            "init [path]",
            "Initialize OpenSpec in your project",
            [
                ("--tools <tools>", "Configure all, none, or a comma-separated list of tool IDs"),
                ("--language <language>", "Write new OpenSpec artifacts in this language"),
                ("--force", "Auto-cleanup legacy files without prompting"),
                ("--profile <profile>", "Override global config profile (core or custom)"),
                ("--no-animation", "Show a static welcome screen instead of the animated one"),
                (
                    "--copilot-cloud",
                    "Set up GitHub Copilot cloud coding-agent files without prompting",
                ),
                (
                    "--no-copilot-cloud",
                    "Skip GitHub Copilot cloud coding-agent files without prompting",
                ),
                (
                    "--scope <scope>",
                    "Where the skills go: global (this machine, for every project) or project",
                ),
            ],
            runInit,
            crash(),
        ),
        (
            "experimental",
            "Alias for init (deprecated)",
            [("--tool <tool-id>", "Target AI tool (maps to --tools)"), noInteractive],
            runExperimental,
            crash(),
        ),
        (
            "update [path]",
            "Update OpenSpec instruction files",
            [
                ("--force", "Force update even when tools are up to date"),
                ("--dry-run", "Report what the update would change without writing anything"),
                ("--json", "With --dry-run, print the planned changes as JSON"),
            ],
            runUpdate,
            crash(
                "update_error",
                lambda (options: any) -> any { rec(changes=[], notes=[], failures=[]) },
                exits=False,
            ),
        ),
        (
            "install [version]",
            "Install the standalone openspec, which runs without Node.js (latest release unless [version] is given)",
            [],
            runInstall,
            crash(),
        ),
        (
            "list",
            "List items (changes by default). Use --specs to list specs.",
            [
                ("--specs", "List specs instead of changes"),
                ("--changes", "List changes explicitly (default)"),
                ("--archived", "Show only archived changes"),
                ("--all", "Show both active and archived changes"),
                ("--sort <order>", "Sort order: \"recent\" (default) or \"name\"", "recent"),
                ("--json", "Output as JSON (for programmatic use)"),
                *STORE,
            ],
            runList,
            crash("list_error", listPayload),
        ),
        ("view", "Display an interactive dashboard of specs and changes", STORE, runView, crash()),
        (
            "change show [change-name]",
            "Show a change proposal in JSON or markdown format",
            [
                json,
                ("--deltas-only", "Show only deltas (JSON only)"),
                ("--requirements-only", "Alias for --deltas-only (deprecated)"),
                ("--diff", "Show per-requirement diffs for delta specs"),
                noInteractive,
            ],
            changeShow,
            reportError,
        ),
        (
            "change list",
            "List all active changes (DEPRECATED: use \"openspec list\" instead)",
            [json, ("--long", "Show id and title with counts")],
            changeList,
            reportError,
        ),
        (
            "change validate [change-name]",
            "Validate a change proposal",
            [
                ("--strict", "Enable strict validation mode"),
                ("--json", "Output validation report as JSON"),
                noInteractive,
            ],
            changeValidate,
            reportError,
        ),
        (
            "archive [change-name]",
            "Archive a completed change and update main specs",
            [
                ("-y, --yes", "Skip confirmation prompts"),
                (
                    "--skip-specs",
                    "Skip spec update operations (useful for infrastructure, tooling, or doc-only changes)",
                ),
                ("--no-validate", "Skip validation (not recommended, requires confirmation)"),
                ("--json", "Output as JSON (non-interactive)"),
                *STORE,
            ],
            runArchive,
            crash(),
        ),
    ];
    trailing: list[any] = [
        (
            "validate [item-name]",
            "Validate changes and specs",
            [
                ("--all", "Validate all changes and specs"),
                ("--changes", "Validate all changes"),
                ("--specs", "Validate all specs"),
                (
                    "--archived",
                    "Validate that archived changes have all tasks completed (for pre-commit linting)",
                ),
                (
                    "--report <full|findings>",
                    "Select bulk report content: full|findings; combine with --json for JSON",
                ),
                ("--type <type>", "Specify item type when ambiguous: change|spec"),
                ("--strict", "Enable strict validation mode"),
                ("--json", "Output validation results as JSON"),
                (
                    "--concurrency <n>",
                    "Max concurrent validations (defaults to env OPENSPEC_CONCURRENCY or 6)",
                ),
                noInteractive,
                *STORE,
            ],
            runValidate,
            crash("validate_error"),
        ),
        (
            "show [item-name]",
            "Show a change or spec",
            [
                json,
                ("--type <type>", "Specify item type when ambiguous: change|spec"),
                noInteractive,
                ("--deltas-only", "Show only deltas (JSON only, change)"),
                ("--requirements-only", "Alias for --deltas-only (deprecated, change)"),
                ("--diff", "Show per-requirement diffs for delta specs (change)"),
                ("--requirements", "JSON only: Show only requirements (exclude scenarios)"),
                ("--no-scenarios", "JSON only: Exclude scenario content"),
                ("-r, --requirement <id>", "JSON only: Show specific requirement by ID (1-based)"),
                *STORE,
            ],
            runShow,
            crash("show_error"),
        ),
        (
            "feedback <message>",
            "Submit feedback about OpenSpec",
            [("--body <text>", "Detailed description for the feedback")],
            runFeedback,
            crash(),
        ),
        (
            "completion generate [shell]",
            "Generate completion script for a shell (outputs to stdout)",
            [],
            completionGenerate,
            crash(),
        ),
        (
            "completion install [shell]",
            "Install completion script for a shell",
            [("--verbose", "Show detailed installation output")],
            completionInstall,
            crash(),
        ),
        (
            "completion uninstall [shell]",
            "Uninstall completion script for a shell",
            [("-y, --yes", "Skip confirmation prompts")],
            completionUninstall,
            crash(),
        ),
        (
            "__complete <type>",
            "Output completion data in machine-readable format (internal use)",
            [],
            complete,
            completeFailed,
        ),
        (
            "status",
            "Display artifact completion status for a change",
            [
                ("--change <id>", "Change name to show status for"),
                ("--all", "Show status for all active changes"),
                schema,
                json,
                *STORE,
            ],
            runStatus,
            crash("change_error", statusPayload),
        ),
        (
            "instructions [artifact]",
            "Output enriched instructions for artifacts, apply, or archive",
            [("--change <id>", "Change name"), schema, json, *STORE],
            runInstructions,
            crash("change_error"),
        ),
        (
            "templates",
            "Show resolved template paths for all artifacts in a schema",
            [
                ("--schema <name>", f"Schema to use (default: {DEFAULT_SCHEMA})"),
                ("--json", "Output as JSON mapping artifact IDs to template paths"),
            ],
            runTemplates,
            crash(),
        ),
        (
            "schemas",
            "List available workflow schemas with descriptions",
            [("--json", "Output as JSON (for agent use)"), *STORE],
            runSchemas,
            crash("schemas_error", lambda (options: any) -> any { rec(schemas=[], root=JsNull) }),
        ),
        (
            "new change <name>",
            "Create a new change directory",
            [
                ("--description <text>", "Description to add to README.md"),
                ("--goal <text>", "Optional goal metadata to store with the change"),
                ("--schema <name>", f"Workflow schema to use (default: {DEFAULT_SCHEMA})"),
                json,
                *STORE,
                ("--initiative <id>", "No longer supported", HIDDEN),
                ("--areas <names>", "No longer supported", HIDDEN),
            ],
            runNewChange,
            crash(),
        ),
    ];
    made: dict[str, any] = {};
    def place(row: any) {
        usage: str = row[0];
        (head, _, rest) = usage.partition(" ");
        if head not in groups {
            define(root_, usage, row[1], row[2], row[3], row[4]);
            return;
        }
        if head not in made {
            made[head] = root_.command(head).description(groups[head]);
            if head == "change" {
                made[head].hook("preAction", deprecatedChange);
            }
        }
        define(made[head], rest, row[1], row[2], row[3], row[4]);
    }
    for row in leading {
        place(row);
    }
    for register in [
        registerSpecCommand,
        registerConfigCommand,
        registerSchemaCommand,
        registerStoreCommand,
        registerDoctorCommand,
        registerContextCommand,
        registerWorksetCommand,
    ] {
        register(root_);
    }
    for row in trailing {
        place(row);
    }
    root_.hook("preAction", beforeAction);
    root_.hook("postAction", afterAction);
    return root_;
}

glob program: any = build();

def runCli(argv: any = None) {
    program.parse(argv ?? process.argv);
}

with entry {
    import from "../core/version-check" { getStandaloneBinaryPath }
    script: any = process.argv[1];
    if not missing(getStandaloneBinaryPath())
        or (script and resolve(script) == join(packageRoot(), "dist", "cli", "index.js"))
    {
        runCli();
    }
}
