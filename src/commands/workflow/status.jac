import from "node:process" { default as process }

type StatusOptions = any;

glob BATCH_STATUS_FAILURE_PAYLOAD: any = rec(changes=[], root=JsNull);

def:priv log(*parts: any) {
    globalThis.console.log(*parts);
}

def:priv printJsonLine(payload: any) {
    log(globalThis.JSON.stringify(payload, None, 2));
}

def:priv stop(spinner: any) {
    if spinner is not None {
        spinner.stop();
    }
}

def:priv failure(changeName: str, error: any) -> any {
    return rec(changeName=changeName, status=[asStatus(error, "change_error")]);
}

async def statusCommand(options: any) {
    if options["all"] and options["change"] {
        raise new(globalThis.Error, "The --all and --change options are mutually exclusive.");
    }
    found = await resolveRootForCommand(
        options,
        rec(
            json=options["json"],
            failurePayload=BATCH_STATUS_FAILURE_PAYLOAD if options["all"] else None,
        ),
    );
    if not truthy(found) {
        return;
    }
    spinner: any = None
        if options["json"]
        else (await load("ora")).default("Loading change status...").start();
    try {
        await showStatus(options, found, spinner);
    } except Exception as e {
        stop(spinner);
        raise js_error(e);
    }
}

async def:priv showStatus(options: any, found: any, spinner: any) {
    planningHome = toPlanningHome(found);
    projectRoot = found.path;
    rootOutput = toRootOutput(found);
    hint = withStoreFlag(found, "openspec new change <name>");
    storeOptions = rec(storeId=found.storeId) if isStoreSelectedRoot(found) else rec();
    implementationRoot = findDeclaringProjectRoot(found.storeId)
        if isStoreSelectedRoot(found)
        else JsNull;
    statusOptions = merge(storeOptions, rec(implementationRoot=implementationRoot))
        if truthy(implementationRoot)
        else storeOptions;
    def loadStatus(changeName: str) -> any {
        return formatChangeStatus(
            loadChangeContext(
                projectRoot,
                changeName,
                options["schema"],
                rec(changeDir=getChangeDir(planningHome, changeName), planningHome=planningHome),
            ),
            statusOptions,
        );
    }
    if not options["change"] {
        if options["all"] and options["schema"] {
            validateSchemaExists(options.schema, projectRoot);
        }
        available: any = await getAvailableChanges(projectRoot, found.changesDir);
        if not available {
            stop(spinner);
            if options["json"] {
                printJsonLine(rec(changes=[], message="No active changes.", root=rootOutput));
            } else {
                log(f"No active changes. Create one with: {hint}");
            }
            return;
        }
        if not options["all"] {
            stop(spinner);
            raise new(
                globalThis.Error,
                "Missing required option --change (or --all for every active change). Available changes:\n  "
                    + "\n  ".join(available),
            );
        }
        nested = {f.name: f for f in await findNestedChanges(found.changesDir, available)};
        entries: list[any] = [];
        for changeName in globalThis.Array.prototype.sort.call(
            available, lambda (a: any, b: any) -> int { a.localeCompare(b) }
        ) {
            if changeName in nested {
                entries.append(
                    failure(
                        changeName, new(globalThis.Error, describeNestedChange(nested[changeName]))
                    ),
                );
                continue;
            }
            try {
                entries.append(loadStatus(changeName));
            } except Exception as e {
                entries.append(failure(changeName, js_error(e)));
            }
        }
        stop(spinner);
        failed = len([e for e in entries if not owns(e, "artifacts")]) > 0;
        if options["json"] {
            printJsonLine(rec(changes=entries, root=rootOutput));
        } else {
            for i in range(len(entries)) {
                item = entries[i];
                if i > 0 {
                    log();
                }
                if owns(item, "artifacts") {
                    printStatusText(item, storeOptions);
                } else {
                    log(pick("chalk").red(f"✗ {item.changeName}: {item.status[0].message}"));
                }
            }
        }
        if failed {
            process.exitCode = 1;
        }
        return;
    }
    changeName = await validateChangeExists(
        options.change, projectRoot, found.changesDir, rec(newChangeHint=hint)
    );
    if options["schema"] {
        validateSchemaExists(options.schema, projectRoot);
    }
    status = loadStatus(changeName);
    stop(spinner);
    if options["json"] {
        printJsonLine(merge(status, rec(root=rootOutput)));
        return;
    }
    printStatusText(status, storeOptions);
}

def printStatusText(status: any, options: any = None) {
    artifacts = status.artifacts;
    done = len([a for a in artifacts if a.status == "done"]);
    skipped = len([a for a in artifacts if a.status == "skipped"]);
    log(f"Change: {status.changeName}");
    log(f"Schema: {status.schemaName}");
    if truthy(status["warnings"]) {
        for warning in status.warnings {
            log(pick("chalk").yellow(f"Warning: {warning}"));
        }
    }
    if status["changeRoot"] {
        log(f"Change root: {status.changeRoot}");
    }
    suffix = f" ({skipped} skipped)" if skipped > 0 else "";
    log(f"Progress: {done}/{len(artifacts) - skipped} artifacts complete{suffix}");
    log();
    for a in artifacts {
        color = getStatusColor(a.status);
        line = f"{getStatusIndicator(a.status)} {a.id}";
        if a.status == "skipped" {
            line += color(" (skipped: change declares skip_specs)");
        }
        deps = a["missingDeps"];
        if a.status == "blocked" and deps {
            line += color(f" (blocked by: {', '.join(deps)})");
        }
        log(line);
    }
    storeId = at(options, "storeId");
    complete = status["isPlanningComplete"];
    nextStep = resolveNextStep(
        merge(
            rec(
                changeName=status.changeName,
                artifactStatuses=artifacts,
                allArtifactsComplete=complete,
            ),
            rec(storeId=storeId) if storeId else None,
        ),
    );
    if complete or truthy(nextStep) {
        log();
    }
    if complete {
        log(pick("chalk").green("All planning artifacts complete!"));
    }
    if truthy(nextStep) {
        log(f"Next: {nextStep.command}");
    }
}
