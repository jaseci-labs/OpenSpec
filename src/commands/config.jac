import from "node:fs" { existsSync, readFileSync }
import from "node:path" { isAbsolute, join }
import from "node:process" { default as process }

glob DELIVERY_RETIRED_NOTE: str = "Note: delivery no longer changes anything; OpenSpec 2.0 installs skills only.";

glob:priv META_ROWS: list[tuple[str, str, str]] = [
    ("propose", "Propose change", "Create proposal, design, and tasks from a request"),
    ("explore", "Explore ideas", "Investigate a problem before implementation"),
    ("new", "New change", "Create a new change scaffold quickly"),
    ("continue", "Continue change", "Resume work on an existing change"),
    ("apply", "Apply tasks", "Implement tasks from the current change"),
    ("update", "Update change", "Revise the planning artifacts of an existing change"),
    ("ff", "Fast-forward", "Run a faster implementation workflow"),
    ("sync", "Sync specs", "Sync change artifacts with specs"),
    ("archive", "Archive change", "Finalize and archive a completed change"),
    ("bulk-archive", "Bulk archive", "Archive multiple completed changes together"),
    ("verify", "Verify change", "Run verification checks against a change"),
    ("onboard", "Onboard", "Guided onboarding flow for OpenSpec"),
];

glob WORKFLOW_PROMPT_META: any = globalThis.Object.fromEntries([
    [k, rec(name=n, description=d)]
    for (k, n, d) in META_ROWS
]);

async def:priv ask(name: str, options: any) -> any {
    return await globalThis.Promise.resolve(merge(await load("@inquirer/prompts"))[name](options));
}

def:priv log(*lines: any) {
    globalThis.console.log(*lines);
}

def:priv refuse(*lines: str) {
    for line in lines {
        globalThis.console.error(line);
    }
    process.exitCode = 1;
}

def splitEditorCommand(value: str, platform: any = None) -> any {
    posix = (platform ?? process.platform) != "win32";
    words: list[str] = [];
    word = "";
    inWord = False;
    quote = "";
    i = 0;
    while i < len(value) {
        ch = value[i];
        i += 1;
        if quote == "'" {
            if ch == "'" {
                quote = "";
            } else {
                word += ch;
            }
        } elif posix and ch == "\\" and i < len(value) {
            if quote == '"' and value[i] not in ['"', "\\"] {
                word += ch;
            } else {
                word += value[i];
                i += 1;
            }
            inWord = True;
        } elif quote == '"' {
            if ch == '"' {
                quote = "";
            } else {
                word += ch;
            }
        } elif ch == '"' or (posix and ch == "'") {
            quote = ch;
            inWord = True;
        } elif found(ch, "\\s") {
            if inWord {
                words.append(word);
            }
            word = "";
            inWord = False;
        } else {
            word += ch;
            inWord = True;
        }
    }
    if quote {
        return JsNull;
    }
    if inWord {
        words.append(word);
    }
    return words;
}

def:priv runEditor(editor: str, filePath: str) -> any {
    def run(resolve: any) {
        words: any = [editor]
            if isAbsolute(editor) and existsSync(editor)
            else splitEditorCommand(editor);
        if words is JsNull or len(words) == 0 {
            problem = "the value has an unterminated quote"
                if words is JsNull
                else "the value is blank";
            resolve(rec(error=new(globalThis.Error, problem)));
            return;
        }
        try {
            args: any = words[1:];
            args.append(filePath);
            child = need("cross-spawn")(words[0], args, rec(stdio="inherit", shell=False));
            child.once("error", lambda (error: any) -> any { resolve(rec(error=error)) });
            child.once(
                "close",
                lambda (code: any, signal: any) -> any { resolve(rec(code=code, signal=signal)) },
            );
        } except Exception as e {
            err = js_error(e);
            resolve(
                rec(
                    error=err
                        if globalThis.Error.prototype.isPrototypeOf(err)
                        else new(globalThis.Error, globalThis.String(err)),
                ),
            );
        }
    }
    return new(globalThis.Promise, run);
}

def:priv reportEditorFailure(editor: str, outcome: any) {
    error: any = outcome["error"];
    if error is not None {
        globalThis.console.error(f'Error: Could not start editor "{editor}": {error.message}');
    } elif outcome["signal"] {
        globalThis.console.error(f'Error: Editor "{editor}" was terminated by {outcome["signal"]}');
    } else {
        globalThis.console.error(
            f'Error: Editor "{editor}" exited with code {globalThis.String(outcome["code"])}'
        );
    }
    if error is not None and at(error, "code") == "ENOENT" {
        globalThis.console.error(
            'Set EDITOR or VISUAL to an installed editor command, for example: export EDITOR="code --wait"',
        );
    }
}

def:priv refuseUnreadableConfig -> bool {
    if not isGlobalConfigUnreadable() {
        return False;
    }
    refuse(
        f"Error: {getGlobalConfigPath()} could not be parsed, so it was left unchanged.",
        'Fix it with "openspec config edit", or reset it with "openspec config reset --all".',
    );
    return True;
}

def resolveCurrentProfileState(config: any) -> any {
    profile = config["profile"] or "core";
    workflows: any = config["workflows"];
    return rec(
        profile=profile,
        delivery=config["delivery"] or "both",
        workflows=[
            w
            for w in getProfileWorkflows(profile, [*workflows] if truthy(workflows) else None)
        ],
    );
}

def deriveProfileFromWorkflowSelection(selectedWorkflows: any) -> str {
    return "core"
        if len(selectedWorkflows) == len(CORE_WORKFLOWS)
            and all([w in selectedWorkflows for w in CORE_WORKFLOWS])
        else "custom";
}

def formatWorkflowSummary(workflows: any, profile: any) -> str {
    return f"{len(workflows)} selected ({profile})";
}

def:priv stableWorkflowOrder(workflows: any) -> list[str] {
    ordered: list[str] = [w for w in ALL_WORKFLOWS if w in workflows];
    ordered.extend(sorted(unique([w for w in workflows if w not in ALL_WORKFLOWS])));
    return ordered;
}

def diffProfileState(before: any, after: any) -> any {
    lines: list[str] = [
        f"{key}: {before[key]} -> {after[key]}"
        for key in ["delivery", "profile"]
        if before[key] != after[key]
    ];
    b = stableWorkflowOrder(before["workflows"]);
    a = stableWorkflowOrder(after["workflows"]);
    changes: list[tuple[str, list[str]]] = [
        ("added", [w for w in a if w not in b]),
        ("removed", [w for w in b if w not in a]),
    ];
    tokens = [f"{label} {', '.join(ws)}" for (label, ws) in changes if ws];
    if tokens {
        lines.append("workflows: " + "; ".join(tokens));
    }
    return rec(hasChanges=len(lines) > 0, lines=lines);
}

def:priv warnIfDrifted(state: any) {
    projectDir = process.cwd();
    if not existsSync(join(projectDir, OPENSPEC_DIR_NAME)) {
        return;
    }
    import from "../core/profile-sync-drift" { hasProjectConfigDrift }
    if hasProjectConfigDrift(projectDir, state.workflows, state.delivery) {
        log(
            pick("chalk").yellow(
                "Warning: Global config is not applied to this project. Run `openspec update` to sync.",
            ),
        );
    }
}

def:priv printApplyGuidance {
    log("Config updated. Run `openspec update` in your projects to apply.");
}

def configPathCommand {
    log(getGlobalConfigPath());
}

def configListCommand(options: any) {
    config = getGlobalConfig();
    if truthy(at(options, "json")) {
        log(globalThis.JSON.stringify(config, None, 2));
        return;
    }
    configPath = getGlobalConfigPath();
    raw: any = rec();
    try {
        if existsSync(configPath) {
            parsed = globalThis.JSON.parse(readFileSync(configPath, "utf-8"));
            if isConfigRootObject(parsed) {
                raw = parsed;
            }
        }
    } except Exception {}
    workflows: any = config["workflows"];
    log(formatValueYaml(config));
    log("\nProfile settings:");
    log(
        f"  profile: {globalThis.String(config['profile'])} "
            + ("(default)" if raw["profile"] is None else "(explicit)"),
    );
    log(f"  delivery: {globalThis.String(config['delivery'])} (retired in 2.0, ignored)");
    if config["profile"] == "core" {
        log(f"  workflows: {', '.join(CORE_WORKFLOWS)} (from core profile)");
    } elif truthy(workflows) and workflows.length > 0 {
        log(f"  workflows: {', '.join([globalThis.String(w) for w in workflows])} (explicit)");
    } else {
        log("  workflows: (none)");
    }
}

def configGetCommand(key: str) {
    value = getNestedValue(getGlobalConfig(), key);
    if value is None {
        process.exitCode = 1;
    } elif kind(value) == "object" and value is not JsNull {
        log(globalThis.JSON.stringify(value));
    } else {
        log(globalThis.String(value));
    }
}

def configSetCommand(key: str, value: str, options: any = None) {
    allowUnknown = truthy(at(options, "allowUnknown"));
    keyValidation = validateConfigKeyPath(key);
    unsafeKey = hasUnsafeKeySegment(key);
    if not keyValidation["valid"] and (not allowUnknown or unsafeKey) {
        reason = f" {keyValidation['reason']}." if keyValidation["reason"] else "";
        lines = [
            f'Error: Invalid configuration key "{key}".{reason}',
            'Use "openspec config list" to see available keys.',
        ];
        if not allowUnknown and not unsafeKey {
            lines.append("Pass --allow-unknown to bypass this check.");
        }
        refuse(*lines);
        return;
    }
    if refuseUnreadableConfig() {
        return;
    }
    config = getGlobalConfig();
    coerced = coerceValue(value, truthy(at(options, "string")));
    candidate = globalThis.JSON.parse(globalThis.JSON.stringify(config));
    setNestedValue(candidate, key, coerced);
    validation = validateConfig(candidate);
    if not validation["success"] {
        refuse(f"Error: Invalid configuration - {validation['error']}");
        return;
    }
    setNestedValue(config, key, coerced);
    saveGlobalConfig(config);
    shown = f'"{coerced}"' if kind(coerced) == "string" else globalThis.String(coerced);
    log(f"Set {key} = {shown}");
    if key == "delivery" {
        log(DELIVERY_RETIRED_NOTE);
    }
}

def configUnsetCommand(key: str) {
    if refuseUnreadableConfig() {
        return;
    }
    config = getGlobalConfig();
    if deleteNestedValue(config, key) {
        saveGlobalConfig(config);
        log(f"Unset {key} (reverted to default)");
    } else {
        log(f'Key "{key}" was not set');
    }
}

async def configResetCommand(options: any) {
    if not truthy(at(options, "all")) {
        refuse(
            "Error: --all flag is required for reset", "Usage: openspec config reset --all [-y]"
        );
        return;
    }
    if not truthy(at(options, "yes")) {
        try {
            confirmed = await ask(
                "confirm", rec(message="Reset all configuration to defaults?", **{"default": False})
            );
        } except Exception as e {
            err = js_error(e);
            if isPromptCancellationError(err) {
                log("Reset cancelled.");
                process.exitCode = 130;
                return;
            }
            raise err;
        }
        if not truthy(confirmed) {
            log("Reset cancelled.");
            return;
        }
    }
    saveGlobalConfig(merge(DEFAULT_CONFIG), rec(replaceUnreadable=True));
    log("Configuration reset to defaults");
}

async def configEditCommand {
    editor: any = process.env["EDITOR"] or process.env["VISUAL"];
    if not editor {
        refuse(
            "Error: No editor configured",
            "Set the EDITOR or VISUAL environment variable to your preferred editor",
            "Example: export EDITOR=vim",
        );
        return;
    }
    configPath = getGlobalConfigPath();
    if not existsSync(configPath) {
        saveGlobalConfig(merge(DEFAULT_CONFIG));
    }
    outcome = await runEditor(editor, configPath);
    if outcome["error"] is not None or not same(outcome["code"], 0) {
        reportEditorFailure(editor, outcome);
        process.exitCode = 1;
        return;
    }
    try {
        validation = validateConfig(globalThis.JSON.parse(readFileSync(configPath, "utf-8")));
        if not validation["success"] {
            refuse(f"Error: Invalid configuration - {validation['error']}");
        }
    } except Exception as e {
        err = js_error(e);
        if at(err, "code") == "ENOENT" {
            refuse(f"Error: Config file not found at {configPath}");
        } elif isinstance(err, globalThis.SyntaxError) {
            refuse(f"Error: Invalid JSON in {configPath}", err.message);
        } else {
            refuse(f"Error: Unable to validate configuration - {messageOf(err)}");
        }
    }
}

def:priv workflowChoice(workflow: str, current: any) -> any {
    meta = WORKFLOW_PROMPT_META[workflow]
        ?? rec(name=workflow, description=f"Workflow: {workflow}");
    return rec(
        value=workflow,
        name=meta.name,
        description=meta.description,
        short=meta.name,
        checked=workflow in current,
    );
}

async def:priv applyToProject(projectDir: str) {
    import from src.core.update { UpdateCommand }
    try {
        command: any = UpdateCommand();
        await command.execute(projectDir);
        log("Run `openspec update` in your other projects to apply.");
    } except Exception as e {
        refuse(
            f"`openspec update` failed: {asErrorMessage(js_error(e))}",
            "Please run it manually to apply the profile changes.",
        );
    }
}

async def configProfileCommand(preset: any = None) {
    if refuseUnreadableConfig() {
        return;
    }
    if preset == "core" {
        config = getGlobalConfig();
        config.profile = "core";
        config.workflows = CORE_WORKFLOWS[:];
        saveGlobalConfig(config);
        printApplyGuidance();
        return;
    }
    if preset {
        refuse(f'Error: Unknown profile preset "{preset}". Available presets: core');
        return;
    }
    if not process.stdout.isTTY {
        refuse(
            "Interactive mode required. Use `openspec config profile core` or set config via environment/flags.",
        );
        return;
    }
    chalk: any = pick("chalk");
    try {
        config = getGlobalConfig();
        current = resolveCurrentProfileState(config);
        log(chalk.bold("\nCurrent profile settings"));
        log(f"  Workflows: {formatWorkflowSummary(current.workflows, current.profile)}");
        log(chalk.dim("  Workflows = which actions are available (propose, explore, apply, etc.)"));
        log();
        action = await ask(
            "select",
            rec(
                message="What do you want to configure?",
                choices=[
                    rec(
                        value="workflows",
                        name="Workflows only",
                        description="Change which workflow actions are available",
                    ),
                    rec(
                        value="keep",
                        name="Keep current settings (exit)",
                        description="Leave configuration unchanged and exit",
                    ),
                ],
            ),
        );
        if action == "keep" {
            log("No config changes.");
            warnIfDrifted(current);
            return;
        }
        nextState = rec(
            profile=current.profile, delivery=current.delivery, workflows=current.workflows[:]
        );
        changed = False;
        if action == "workflows" {
            selected: any = await ask(
                "checkbox",
                rec(
                    message="Select workflows to make available:",
                    pageSize=len(ALL_WORKFLOWS),
                    theme=rec(icon=rec(checked="[x]", unchecked="[ ]")),
                    choices=[workflowChoice(w, current.workflows) for w in ALL_WORKFLOWS],
                ),
            );
            nextState.workflows = selected;
            changed = len(selected) != len(current.workflows)
                or any([w not in current.workflows for w in selected]);
            nextState.profile = deriveProfileFromWorkflowSelection(selected)
                if changed
                else current.profile;
        }
        diff = diffProfileState(current, nextState);
        if not diff.hasChanges {
            log("No config changes.");
            warnIfDrifted(nextState);
            return;
        }
        log(chalk.bold("\nConfig changes:"));
        for line in diff.lines {
            log(f"  {line}");
        }
        log();
        config.profile = nextState.profile;
        config.delivery = nextState.delivery;
        if current.profile != "custom" or changed {
            config.workflows = nextState.workflows;
        }
        saveGlobalConfig(config);
        projectDir = process.cwd();
        if existsSync(join(projectDir, OPENSPEC_DIR_NAME))
            and truthy(
                await ask(
                    "confirm",
                    rec(message="Apply changes to this project now?", **{"default": True}),
                ),
            )
        {
            await applyToProject(projectDir);
            return;
        }
        printApplyGuidance();
    } except Exception as e {
        err = js_error(e);
        if isPromptCancellationError(err) {
            log("Config profile cancelled.");
            process.exitCode = 130;
            return;
        }
        raise err;
    }
}
