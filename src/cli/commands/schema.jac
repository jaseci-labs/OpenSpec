def:priv experimentalNote {
    globalThis.console.error("Note: Schema commands are experimental and may change.");
}

async def:priv runWhich(name: any, options: any) {
    import from src.commands.schema { schemaWhichCommand }
    await schemaWhichCommand(name, options);
}

async def:priv runValidate(name: any, options: any) {
    import from src.commands.schema { schemaValidateCommand }
    await schemaValidateCommand(name, options);
}

async def:priv runFork(source: str, name: any, options: any) {
    import from src.commands.schema { schemaForkCommand }
    await schemaForkCommand(source, name, options);
}

async def:priv runInit(name: str, options: any) {
    import from src.commands.schema { schemaInitCommand }
    await schemaInitCommand(name, options);
}

def registerSchemaCommand(program: any) {
    schemaCmd = program.command("schema").description("Manage workflow schemas [experimental]");
    schemaCmd.hook("preAction", experimentalNote);
    json = ("--json", "Output as JSON");
    subcommands: list[tuple[str, str, list[tuple[str, str]], any]] = [
        (
            "which [name]",
            "Show where a schema resolves from",
            [json, ("--all", "List all schemas with their resolution sources")],
            runWhich,
        ),
        (
            "validate [name]",
            "Validate a schema structure and templates",
            [json, ("--verbose", "Show detailed validation steps")],
            runValidate,
        ),
        (
            "fork <source> [name]",
            "Copy an existing schema to project for customization",
            [json, ("--force", "Overwrite existing destination")],
            runFork,
        ),
        (
            "init <name>",
            "Create a new project-local schema",
            [
                json,
                ("--description <text>", "Schema description"),
                (
                    "--artifacts <list>",
                    "Comma-separated artifact IDs (proposal,specs,design,tasks)",
                ),
                ("--default", "Set as project default schema"),
                ("--no-default", "Do not prompt to set as default"),
                ("--force", "Overwrite existing schema"),
            ],
            runInit,
        ),
    ];
    for (spec, description, flags, run) in subcommands {
        cmd = schemaCmd.command(spec).description(description);
        for (flag, text) in flags {
            cmd.option(flag, text);
        }
        cmd.action(run);
    }
}
