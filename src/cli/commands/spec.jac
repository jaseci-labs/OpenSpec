def:priv deprecationNote {
    globalThis.console.error(
        "Warning: The \"openspec spec ...\" commands are deprecated. Prefer verb-first commands (e.g., \"openspec show\", \"openspec validate --specs\").",
    );
}

async def:priv runShow(specId: any, options: any) {
    import from src.commands.spec { specShowCommand }
    await specShowCommand(specId, options);
}

async def:priv runList(options: any) {
    import from src.commands.spec { specListCommand }
    await specListCommand(options);
}

async def:priv runValidate(specId: any, options: any) {
    import from src.commands.spec { specValidateCommand }
    await specValidateCommand(specId, options);
}

def registerSpecCommand(rootProgram: any) -> any {
    specCommand = rootProgram.command("spec").description(
        "Manage and view OpenSpec specifications"
    );
    specCommand.hook("preAction", deprecationNote);
    json = ("--json", "Output as JSON");
    noInteractive = ("--no-interactive", "Disable interactive prompts");
    subcommands: list[tuple[str, str, list[tuple[str, str]], any]] = [
        (
            "show [spec-id]",
            "Display a specific specification",
            [
                json,
                ("--requirements", "JSON only: Show only requirements (exclude scenarios)"),
                ("--no-scenarios", "JSON only: Exclude scenario content"),
                ("-r, --requirement <id>", "JSON only: Show specific requirement by ID (1-based)"),
                noInteractive,
            ],
            runShow,
        ),
        (
            "list",
            "List all available specifications",
            [json, ("--long", "Show id and title with counts")],
            runList,
        ),
        (
            "validate [spec-id]",
            "Validate a specification structure",
            [
                ("--strict", "Enable strict validation mode"),
                ("--json", "Output validation report as JSON"),
                noInteractive,
            ],
            runValidate,
        ),
    ];
    for (spec, description, flags, run) in subcommands {
        cmd = specCommand.command(spec).description(description);
        for (flag, text) in flags {
            cmd.option(flag, text);
        }
        cmd.action(run);
    }
    return specCommand;
}
