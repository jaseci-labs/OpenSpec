import from "node:process" { default as process }
import from "node:path" { join }
import from "node:url" { pathToFileURL }

def:priv runner(action: str) -> any {
    async def run(arg: any, options: any) {
        implementation = await load(
            pathToFileURL(join(packageRoot(), "dist", "commands", "store.js")).href
        );
        await implementation.runStoreAction(action, arg, options);
    }
    return run;
}

def:priv registryEntry(name: str) -> any {
    for item in COMMAND_REGISTRY {
        if item.name == name {
            return item;
        }
    }
    return None;
}

def:priv hasStoreFlag(flags: any) -> bool {
    for flag in flags {
        if flag.name == "store" {
            return True;
        }
    }
    return False;
}

def registerStoreCommand(program: any) {
    store = program.command("store").description(
        at(registryEntry("store"), "description")
            ?? "Create and manage stores - standalone OpenSpec repos you register on this machine",
    );
    json = ("--json", "Output as JSON");
    subcommands: list[tuple[str, str, str, list[tuple[str, str]]]] = [
        (
            "setup",
            "setup [id]",
            "Create and register a local store",
            [
                (
                    "--path <path>",
                    "Folder where the store should live (for example ~/openspec/<id>)",
                ),
                ("--init-git", "Initialize a Git repository with an initial commit (default)"),
                ("--no-init-git", "Skip every Git action: no init, no initial commit"),
                ("--remote <url>", "Canonical clone source recorded in store.yaml"),
                json,
            ],
        ),
        (
            "register",
            "register [path]",
            "Register an existing local store",
            [
                ("--id <id>", "Store id; defaults to metadata or folder name"),
                ("--yes", "Confirm creating store identity metadata for a healthy OpenSpec root"),
                json,
            ],
        ),
        (
            "unregister",
            "unregister <id>",
            "Forget a local store registration without deleting files",
            [json],
        ),
        (
            "remove",
            "remove <id>",
            "Forget a local store registration and delete its local folder",
            [("--yes", "Confirm local store folder deletion"), json],
        ),
        ("list", "list", "List locally registered stores", [json]),
        ("doctor", "doctor [id]", "Check local store registration and metadata", [json]),
    ];
    for (action, spec, description, flags) in subcommands {
        cmd = store.command(spec);
        if action == "list" {
            cmd.alias("ls");
        }
        cmd.description(description);
        for (flag, text) in flags {
            cmd.option(flag, text);
        }
        cmd.action(runner(action));
    }
    lifecycleRedirects = [
        item.name
        for item in COMMAND_REGISTRY
        if hasStoreFlag(item.flags)
            or any([hasStoreFlag(s.flags) for s in (item["subcommands"] ?? [])])
    ];
    names: list[str] = [];
    for subcommand in store.commands {
        aliases: any = subcommand.aliases();
        names.append(
            f"{subcommand.name()} ({aliases.join(', ')})" if len(aliases) > 0 else subcommand.name()
        );
    }
    line = ", ".join(names);
    store.allowExcessArguments(True);
    store.allowUnknownOption(True);
    def fallback {
        operands: any = store.args;
        attempted = [o for o in operands if not o.startsWith("-")];
        flagged = len(attempted) < len(operands);
        if "--json" in operands {
            message = f"Unknown command '{attempted[0]}' for 'openspec store'. Store subcommands: {line}."
                if attempted
                else f"Missing subcommand for 'openspec store'. Store subcommands: {line}.";
            printJson(
                rec(
                    status=[
                        rec(
                            severity="error",
                            code="unknown_store_subcommand",
                            message=message,
                            fix="Run a store subcommand, or use the lifecycle command with --store <id>.",
                        ),
                    ],
                ),
            );
            process.exitCode = 1;
            return;
        }
        example = "openspec new change <change-id> --store <id>";
        if not flagged and attempted and attempted[0] in lifecycleRedirects {
            if attempted[0] == "new" {
                changeId = attempted[2]
                    if len(attempted) > 2 and attempted[1] == "change" and attempted[2]
                    else "<change-id>";
                example = f"openspec new change {changeId} --store <id>";
            } else {
                example = f"openspec {' '.join(attempted)} --store <id>";
            }
        }
        globalThis.console.error(
            f"Error: unknown command '{attempted[0]}' for 'openspec store'."
                if attempted
                else "Error: missing subcommand for 'openspec store'.",
        );
        globalThis.console.error(f"Store subcommands manage store registration: {line}.");
        globalThis.console.error(
            "To create or work on a change in a store, use the normal command with --store, for example:",
        );
        globalThis.console.error(f"  {example}");
        process.exitCode = 1;
    }
    store.action(fallback);
}
