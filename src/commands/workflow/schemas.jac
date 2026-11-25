type SchemasOptions = any;

async def schemasCommand(options: any) {
    found = await resolveRootForCommand(
        options, rec(json=options["json"], failurePayload=rec(schemas=[], root=JsNull))
    );
    if not truthy(found) {
        return;
    }
    schemas = listSchemasWithInfo(found.path);
    if options["json"] {
        globalThis.console.log(globalThis.JSON.stringify(schemas, None, 2));
        return;
    }
    chalk: any = pick("chalk");
    globalThis.console.log("Available schemas:");
    globalThis.console.log();
    for s in schemas {
        label = chalk.cyan(" (project)")
            if s.source == "project"
            else chalk.dim(" (user override)") if s.source == "user" else "";
        globalThis.console.log(f"  {chalk.bold(s.name)}{label}");
        globalThis.console.log(f"    {s.description}");
        globalThis.console.log(f"    Artifacts: {' → '.join(s.artifacts)}");
        globalThis.console.log();
    }
}
