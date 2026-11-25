import from "node:process" { default as process }

def:priv commands -> any {
    import from src.commands.config {
        configPathCommand,
        configListCommand,
        configGetCommand,
        configSetCommand,
        configUnsetCommand,
        configResetCommand,
        configEditCommand,
        configProfileCommand,
    }
    return rec(
        path=configPathCommand,
        list_=configListCommand,
        get=configGetCommand,
        set=configSetCommand,
        unset=configUnsetCommand,
        reset=configResetCommand,
        edit=configEditCommand,
        profile=configProfileCommand,
    );
}

def:priv checkScope(thisCommand: any) {
    scope: any = thisCommand.opts()["scope"];
    if scope and scope != "global" {
        globalThis.console.error("Error: Project-local config is not yet implemented");
        process.exit(1);
    }
}

def registerConfigCommand(program: any) {
    configCmd = program.command("config").description(
        "View and modify global OpenSpec configuration"
    );
    configCmd.option("--scope <scope>", 'Config scope (only "global" supported currently)');
    configCmd.hook("preAction", checkScope);
    subcommands: list[tuple[str, str, list[tuple[str, str]], any]] = [
        ("path", "Show config file location", [], lambda -> any { commands().path() }),
        (
            "list",
            "Show all current settings",
            [("--json", "Output as JSON")],
            lambda (options: any) -> any { commands().list_(options) },
        ),
        (
            "get <key>",
            "Get a specific value (raw, scriptable)",
            [],
            lambda (key: any) -> any { commands().get(key) },
        ),
        (
            "set <key> <value>",
            "Set a value (auto-coerce types)",
            [
                ("--string", "Force value to be stored as string"),
                ("--allow-unknown", "Allow setting unknown keys"),
            ],
            lambda (key: any, value: any, options: any) -> any {
                commands().set(key, value, options)
            },
        ),
        (
            "unset <key>",
            "Remove a key (revert to default)",
            [],
            lambda (key: any) -> any { commands().unset(key) },
        ),
        (
            "reset",
            "Reset configuration to defaults",
            [
                ("--all", "Reset all configuration (required)"),
                ("-y, --yes", "Skip confirmation prompts"),
            ],
            lambda (options: any) -> any { commands().reset(options) },
        ),
        ("edit", "Open config in $EDITOR", [], lambda -> any { commands().edit() }),
        (
            "profile [preset]",
            "Configure workflow profile (interactive picker or preset shortcut)",
            [],
            lambda (preset: any) -> any { commands().profile(preset) },
        ),
    ];
    for (spec, description, flags, run) in subcommands {
        cmd = configCmd.command(spec).description(description);
        for (flag, text) in flags {
            cmd.option(flag, text);
        }
        cmd.action(run);
    }
}
