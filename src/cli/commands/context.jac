import from "node:path" { join }
import from "node:url" { pathToFileURL }

async def:priv runContext(options: any) {
    implementation = await load(
        pathToFileURL(join(packageRoot(), "dist", "commands", "context.js")).href
    );
    await implementation.contextCommand(options);
}

def registerContextCommand(program: any) {
    described = [c.description for c in COMMAND_REGISTRY if c.name == "context"];
    program.command("context").description(
        described[0] if described else "Print the working context for the resolved OpenSpec root"
    ).option("--store <id>", COMMON_FLAGS.store.description).addOption(
        new(
            pick("commander", "Option"),
            "--store-path <path>",
            "Removed; register the store and use --store",
        ).hideHelp(),
    ).option("--json", "Output the agent brief as JSON").option(
        "--code-workspace <path>", "Also write a VS Code workspace file for the set"
    ).option("--force", "Overwrite an existing --code-workspace file").action(runContext);
}
