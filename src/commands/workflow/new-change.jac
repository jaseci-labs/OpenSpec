import from "node:fs" { promises as fsp }
import from "node:path" { default as path }
import from "node:process" { default as process }

type NewChangeOptions = any;

glob:priv REMOVED_OPTIONS: list[tuple[str, str, str]] = [
    (
        "initiative",
        "--initiative is no longer supported. Normal changes no longer attach to initiatives; --store <id> selects the OpenSpec root.",
        "initiative_option_removed",
    ),
    (
        "areas",
        "--areas is no longer supported. Workspace affected areas are not part of the normal OpenSpec root path.",
        "areas_option_removed",
    ),
];

def:priv printImplicitRootNotice(found: any) {
    if found.source != "implicit" {
        return;
    }
    openspecDir = path.dirname(found.changesDir);
    rel: any = path.relative(process.cwd(), openspecDir);
    location = rel if rel and not rel.startsWith("..") else openspecDir;
    chalk: any = pick("chalk");
    globalThis.console.log();
    globalThis.console.log(
        chalk.dim(f"Note: no OpenSpec root was found here, so one was created at {location}/.")
    );
    globalThis.console.log(
        chalk.dim(
            "Run `openspec init` to finish setting this project up, or delete that directory if you meant a different project.",
        ),
    );
}

async def newChangeCommand(name: any, options: any) {
    spinner: any = None if options["json"] else (await load("ora")).default();
    try {
        if not name {
            raise new(globalThis.Error, "Missing required argument <name>");
        }
        validation = validateChangeName(name);
        if not validation.valid {
            raise new(globalThis.Error, validation.error);
        }
        for (key, message, code) in REMOVED_OPTIONS {
            if options[key] is not None {
                raise RootSelectionError(message, code, rec(target="change.options"));
            }
        }
        found = await resolveRootForCommand(
            options, rec(json=options["json"], failurePayload=rec(change=JsNull))
        );
        if not truthy(found) {
            return;
        }
        projectRoot = found.path;
        if options["schema"] {
            validateSchemaExists(options.schema, projectRoot);
        }
        schema = options["schema"]
            or (at(readProjectConfig(projectRoot), "schema") ?? found.defaultSchema);
        if spinner is not None {
            spinner.start(f"Creating change '{name}' with schema '{schema}'...");
        }
        result = await createChange(
            projectRoot,
            name,
            rec(
                schema=schema,
                defaultSchema=found.defaultSchema,
                changesDir=found.changesDir,
                metadata=merge(rec(goal=options.goal) if options["goal"] else None),
            ),
        );
        if options["description"] {
            await fsp.writeFile(
                path.join(result.changeDir, "README.md"),
                f"# {name}\n\n{options.description}\n",
                "utf-8",
            );
        }
        if options["json"] {
            printJson(
                rec(
                    change=rec(
                        id=name,
                        path=result.changeDir,
                        metadataPath=path.join(result.changeDir, ".openspec.yaml"),
                        schema=result.schema,
                    ),
                    root=toRootOutput(found),
                ),
            );
            return;
        }
        if spinner is not None {
            spinner.stop();
        }
        location = formatChangeLocation(toPlanningHome(found), name)
            if not isStoreSelectedRoot(found) and found.path == process.cwd()
            else result.changeDir;
        globalThis.console.log(f"Created change '{name}' at {location}/");
        globalThis.console.log(f"Schema: {result.schema}");
        globalThis.console.log(f"Next: {withStoreFlag(found, f'openspec status --change {name}')}");
        printImplicitRootNotice(found);
    } except Exception as e {
        err = js_error(e);
        if spinner is not None {
            spinner.stop();
        }
        if options["json"] {
            printJson(rec(change=JsNull, status=[statusFromError(err)]));
            process.exitCode = 1;
            return;
        }
        raise err;
    }
}
