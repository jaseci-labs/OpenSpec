import from "node:process" { default as process }

async def:priv worksetCommand -> any {
    import from src.commands.workset { WorksetCommand }
    return WorksetCommand();
}

async def:priv runCreate(name: any, options: any, command: any) {
    await (await worksetCommand()).create(name, command.optsWithGlobals());
}

async def:priv runList(options: any, command: any) {
    await (await worksetCommand()).ls(command.optsWithGlobals());
}

async def:priv runOpen(name: str, options: any, command: any) {
    await (await worksetCommand()).open(name, command.optsWithGlobals());
}

async def:priv runRemove(name: str, options: any, command: any) {
    await (await worksetCommand()).remove(name, command.optsWithGlobals());
}

def registerWorksetCommand(program: any) {
    registered = [e for e in COMMAND_REGISTRY if e.name == "workset"];
    workset = program.command("workset").description(
        registered[0].description
            if registered
            else "Compose, keep, and open personal working views (purely local)",
    );
    json = "--json";
    workset.addOption(workset.createOption(json, "Output as JSON").hideHelp());
    create = workset.command("create [name]").description(
        "Compose and save a named working view of folders you choose"
    );
    create.option(
        "--member <member>",
        "Member folder as <path> or <name>=<path>; repeatable, first is the primary",
        lambda (value: any, previous: any) -> any { [*previous, value] },
        [],
    );
    create.option("--tool <id>", "Preferred tool to open this workset with").option(
        json, "Output as JSON"
    ).action(runCreate);
    workset.command("list").alias("ls").description(
        "Show saved worksets with their members"
    ).option(json, "Output as JSON").action(runList);
    opener = workset.command("open <name>").description(
        "Open a saved workset in your tool (editor window or agent session)"
    );
    opener.option("--tool <id>", "Open with this tool just this once").addOption(
        opener.createOption(json, "Not supported for open").hideHelp()
    ).action(runOpen);
    workset.command("remove <name>").description(
        "Delete a saved workset (member folders are never touched)"
    ).option("--yes", "Confirm removal non-interactively").option(json, "Output as JSON").action(
        runRemove
    );
    names: any = [];
    for c in workset.commands {
        aliases: any = c.aliases();
        names.append(f"{c.name()} ({aliases.join(', ')})" if len(aliases) else c.name());
    }
    subcommands = ", ".join(names);
    def unknownSubcommand {
        attempted = [a for a in workset.args if not a.startswith("-")];
        message = f"Unknown command '{attempted[0]}' for 'openspec workset'. Workset subcommands: {subcommands}."
            if attempted
            else f"Missing subcommand for 'openspec workset'. Workset subcommands: {subcommands}.";
        if workset.opts()["json"] {
            printJson(
                rec(
                    status=[
                        rec(
                            severity="error",
                            code="unknown_workset_subcommand",
                            message=message,
                            fix="Run one of the workset subcommands.",
                        ),
                    ],
                ),
            );
        } else {
            globalThis.console.error(f"Error: {message}");
        }
        process.exitCode = 1;
    }
    workset.allowExcessArguments(True);
    workset.action(unknownSubcommand);
}
