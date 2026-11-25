import from "node:fs" { existsSync, writeFileSync }
import from "node:path" { default as path }

type ContextOptions = any;

def:priv log(text: str) {
    globalThis.console.log(text);
}

def:priv rootLabel(workingSet: any) -> str {
    return workingSet.root["store_id"] ?? path.basename(workingSet.root.path);
}

async def:priv gatherWorkingSet(root_: any) -> tuple[any, int] {
    data = await gatherRelationshipData(root_);
    health = inspectRelationships(
        rec(
            root=root_,
            rootHealthy=data.rootInspection.healthy,
            rootStatus=data.rootInspection.diagnostics,
            referenceEntries=data.referenceEntries,
            registryUnreadable=data.registrySnapshot.unreadable,
        ),
    );
    return (
        assembleWorkingSet(
            rec(root=root_, referenceEntries=data.referenceEntries, topLevelStatus=health.status)
        ),
        len(at(data.projectConfig, "references") ?? []),
    );
}

def:priv printHumanWorkingSet(workingSet: any, declared: int) {
    label = rootLabel(workingSet);
    members = workingSet.members;
    log(f"Working context for {label} ({workingSet.root.path})");
    log("");
    log("OpenSpec root");
    log(f"  {label}  {workingSet.root.path}");
    available = [m for m in members if m.role == "referenced_store" and isAvailableMember(m)];
    unavailable = [m for m in members if not isAvailableMember(m)];
    if available {
        log("");
        log("Referenced stores");
        for m in available {
            log(f"  {m.id}  {m.path}");
            if m["fetch"] {
                log(f"    Fetch: {m.fetch}");
            }
        }
    }
    if len(members) == 0 {
        log("");
        log(
            "Declared references all resolve to this root; the working set is this root alone."
                if declared > 0
                else "No references declared; the working set is this root alone.",
        );
    }
    if unavailable or len(workingSet.status) > 0 {
        log("");
        log("Not available on this machine");
        for m in unavailable {
            if len(m.status) == 0 {
                log(f"  - {m.id}");
            }
            for d in m.status {
                log(f"  - {m.id}: {d.message}");
                if d["fix"] {
                    log(f"    Fix: {d.fix}");
                }
            }
        }
        for d in workingSet.status {
            log(f"  Note: {d.message}");
            if d["fix"] {
                log(f"  Fix: {d.fix}");
            }
        }
    }
}

def:priv writeCodeWorkspace(workingSet: any, outputPath: str, force: bool) {
    resolved = path.resolve(outputPath);
    if existsSync(resolved) and not force {
        raise StoreError(
            f"Refusing to overwrite {resolved}.",
            "context_file_exists",
            rec(
                target="context.output",
                fix="Pass --force to overwrite, or choose a different path.",
            ),
        );
    }
    parent = path.dirname(resolved);
    if not existsSync(parent) {
        raise StoreError(
            f"Output directory does not exist: {parent}.",
            "context_output_dir_missing",
            rec(target="context.output", fix="Create the directory first, or choose another path."),
        );
    }
    writeFileSync(resolved, buildCodeWorkspaceJson(workingSet, rootLabel(workingSet)));
    available = len([m for m in workingSet.members if isAvailableMember(m)]);
    skipped = [m.id for m in workingSet.members if not isAvailableMember(m)];
    globalThis.console.error(
        f"Wrote {resolved} ({available + 1} folders; not available: {', '.join(skipped)})"
            if skipped
            else f"Wrote {resolved} ({available + 1} folders)",
    );
}

async def contextCommand(options: any) {
    failure = rec(root=JsNull, members=[]);
    try {
        root_ = await resolveRootForCommand(
            rec(store=options["store"], storePath=options["storePath"]),
            rec(json=options["json"], failurePayload=failure, allowImplicitRoot=False),
        );
        if not truthy(root_) {
            return;
        }
        (workingSet, declared) = await gatherWorkingSet(root_);
        target = options["codeWorkspace"];
        force = same(options["force"], True);
        if options["json"] {
            if target {
                writeCodeWorkspace(workingSet, target, force);
            }
            printJson(workingSet);
        } else {
            printHumanWorkingSet(workingSet, declared);
            if target {
                writeCodeWorkspace(workingSet, target, force);
            }
        }
    } except Exception as e {
        emitFailure(options["json"], failure, js_error(e), "context_failed");
    }
}
