import from "node:os" { homedir }
import from "node:path" { default as path }

type StoreSetupOptions = any;
type StoreRegisterOptions = any;
type StoreRemoveOptions = any;
type StoreJsonOptions = any;

def:priv log(text: str) {
    globalThis.console.log(text);
}

def:priv orElse(value: any, fallback: any) -> any {
    return fallback if missing(value) else value;
}

def:priv refuse(message: str, code: str, target: str, fix: str) -> any {
    return StoreError(message, code, rec(target=target, fix=fix));
}

async def:priv ask(kind_: str, options: any) -> any {
    return await globalThis.Promise.resolve(merge(await load("@inquirer/prompts"))[kind_](options));
}

def:priv toStoreOutput(store: any) -> any {
    return merge(
        rec(id=store.id, root=store.root),
        rec(metadata_path=store.metadataPath) if truthy(store["metadataPath"]) else None,
    );
}

def:priv toMutationOutput(result: any) -> any {
    commit = result.registryCommit;
    git = result.git;
    return rec(
        store=toStoreOutput(result.store),
        registry=rec(
            path=commit.path,
            registered=commit.registered,
            already_registered=commit.alreadyRegistered,
        ),
        git=rec(
            is_repository=git.isRepository, initialized=git.initialized, committed=git.committed
        ),
        created_files=result.createdArtifacts,
        status=result.diagnostics,
    );
}

def:priv toCleanupOutput(result: any) -> any {
    files = result.files;
    return rec(
        store=toStoreOutput(result.store),
        registry=rec(path=result.registryCommit.path, removed=result.registryCommit.removed),
        files=rec(
            deleted=files.deleted,
            deleted_path=orElse(files["deletedPath"], JsNull),
            left_on_disk=orElse(files["leftOnDisk"], JsNull),
        ),
        status=result.diagnostics,
    );
}

def:priv toListOutput(result: any) -> any {
    return rec(stores=[toStoreOutput(s) for s in result.stores], status=[]);
}

def:priv toDoctorStoreOutput(store: any) -> any {
    root_ = store.openspecRoot;
    git = store.git;
    return merge(
        toStoreOutput(store),
        rec(
            openspec_root=rec(
                present=root_.present,
                config=root_.config,
                specs=root_.specs,
                changes=root_.changes,
                archive=root_.archive,
                healthy=root_.healthy,
                status=root_.diagnostics,
            ),
            metadata=store.metadata,
            git=rec(
                is_repository=git.isRepository,
                has_commits=git.hasCommits,
                has_uncommitted_changes=git.hasUncommittedChanges,
                has_remote=git.hasRemote,
                origin_url=git.originUrl,
            ),
            status=store.diagnostics,
        ),
    );
}

def:priv toDoctorOutput(result: any) -> any {
    return rec(stores=[toDoctorStoreOutput(s) for s in result.stores], status=result.diagnostics);
}

def:priv formatPathForHuman(targetPath: str) -> str {
    home = path.resolve(homedir());
    target: any = path.resolve(targetPath);
    if target == home {
        return "~";
    }
    if target.startsWith(f"{home}{path.sep}") {
        return f"~{path.sep}{path.relative(home, target)}";
    }
    return targetPath;
}

async def:priv promptStoreId -> any {
    def valid(value: str) -> any {
        try {
            validateStoreId(value);
            return True;
        } except Exception as e {
            return asErrorMessage(js_error(e));
        }
    }
    return await ask("input", rec(message="Store name", required=True, validate=valid));
}

async def:priv resolveSetupInput(id: any, options: any) -> any {
    interactive = not options["json"] and isInteractive();
    shown = "<id>" if id is None else id;
    if not id and not interactive {
        raise refuse(
            "Pass a store name.",
            "store_setup_id_required",
            "store.id",
            "openspec store setup <id> --path ~/openspec/<id> --json",
        );
    }
    if options["path"] is None and not interactive {
        raise refuse(
            "Pass --path with the folder where this store should live.",
            "store_setup_path_required",
            "store.root",
            f"openspec store setup {shown} --path ~/openspec/{shown}",
        );
    }
    resolvedId = validateStoreId(id) if id else await promptStoreId();
    chosen = options["path"];
    if chosen is None {
        chosen = await ask(
            "input",
            rec(
                message="Where should this store live?",
                prefill="editable",
                required=True,
                **{"default": "/".join(["~", "openspec", resolvedId])},
            ),
        );
    }
    return merge(
        rec(id=resolvedId, path=chosen),
        None if options["remote"] is None else rec(remote=options.remote),
    );
}

async def:priv confirmOrRefuse(message: str, fallback: bool, refusal: any) {
    if not await ask("confirm", rec(message=message, **{"default": fallback})) {
        raise refusal;
    }
}

async def:priv setupFlow(id: any, options: any) -> any {
    prepared = await prepareStoreSetup(
        merge(
            await resolveSetupInput(id, options),
            None if options["initGit"] is None else rec(initGit=options.initGit),
        ),
    );
    initGit = resolveSetupGitEnabled(prepared, options["initGit"]);
    if not options["json"] and isInteractive() {
        for line in [
            "",
            "OpenSpec will create:",
            "",
            f"  Store: {prepared.id}",
            f"  Location: {formatPathForHuman(prepared.root)}",
            f"  Git: {'initialized' if initGit else 'not initialized'}",
            "",
        ] {
            log(line);
        }
        await confirmOrRefuse(
            "Create this store?",
            True,
            refuse(
                "Store setup cancelled.",
                "store_setup_cancelled",
                "store.root",
                "Rerun setup when you are ready.",
            ),
        );
    }
    return await setupPreparedStore(prepared, rec(initGit=initGit));
}

async def:priv registerFlow(inputPath: any, options: any) -> any {
    request = rec(path=inputPath, id=options["id"], allowCreateIdentity=options["yes"]);
    try {
        return await registerExistingStore(request);
    } except Exception as e {
        err = js_error(e);
        if not (
            isinstance(err, StoreError)
            and err.diagnostic.code == "store_register_identity_confirmation_required"
        )
            or options["json"]
            or not isInteractive()
        {
            raise err;
        }
        await confirmOrRefuse(
            asErrorMessage(err),
            False,
            refuse(
                "Store register cancelled.",
                "store_register_cancelled",
                "store.metadata",
                "Rerun register when you are ready to create store identity metadata.",
            ),
        );
    }
    return await registerExistingStore(merge(request, rec(allowCreateIdentity=True)));
}

async def:priv removeFlow(id: str, options: any) -> any {
    target = await prepareStoreCleanup(rec(id=id));
    if not options["yes"] {
        if options["json"] or not isInteractive() {
            raise refuse(
                "Pass --yes to delete store files non-interactively.",
                "store_remove_confirmation_required",
                "store.root",
                f"openspec store remove {target.id} --yes",
            );
        }
        await confirmOrRefuse(
            f"Delete local store folder {formatPathForHuman(target.root)}?",
            False,
            refuse(
                "Store remove cancelled.",
                "store_remove_cancelled",
                "store.root",
                'Run "openspec store unregister <id>" if you only want to forget the local registration.',
            ),
        );
    }
    return await removeStore(target);
}

def:priv printStatusNotes(status: any) {
    for s in status {
        log(f"{'Issue' if s.severity == 'error' else 'Note'}: {s.message}");
    }
}

def:priv mutationPrinter(title: str) -> any {
    def show(payload: any, result: any) {
        log(f"{title}: {payload.store.id}");
        log(f"Location: {formatPathForHuman(payload.store.root)}");
        log("OpenSpec root: ready");
        log(
            f"Registry: {'already registered' if payload.registry.already_registered else 'registered'}",
        );
        printStatusNotes(payload.status);
        log("");
        log("Next: run normal OpenSpec commands against this store, for example:");
        log(f"  openspec new change <change-id> --store {payload.store.id}");
        if payload.git.is_repository {
            remotes = result["remotes"];
            shareRemote = orElse(at(remotes, "canonical"), at(remotes, "observed"));
            log(
                f"Share it: teammates clone {shareRemote} and run openspec store register <path>."
                    if truthy(shareRemote)
                    else "Share this store by committing and pushing it like any Git repo.",
            );
        }
    }
    return show;
}

def:priv cleanupPrinter(title: str) -> any {
    def show(payload: any, result: any) {
        files = payload.files;
        log(f"{title}: {payload.store.id}");
        if truthy(files.deleted_path) {
            log(f"Deleted: {formatPathForHuman(files.deleted_path)}");
        } elif truthy(files.left_on_disk) {
            log(f"Files kept at: {formatPathForHuman(files.left_on_disk)}");
        } elif not files.deleted {
            log(f"Files were already missing: {formatPathForHuman(payload.store.root)}");
        }
        printStatusNotes(payload.status);
    }
    return show;
}

def:priv printList(payload: any, result: any) {
    if len(payload.stores) == 0 {
        for line in [
            "No stores registered.",
            "",
            "Next:",
            "  openspec store setup team-context --path ~/openspec/team-context",
            "  openspec store register /path/to/store",
        ] {
            log(line);
        }
        return;
    }
    log(f"OpenSpec stores ({len(payload.stores)})");
    log("");
    log("ID              Location");
    for store in payload.stores {
        id: any = store.id;
        log(f"{id.padEnd(16)}{store.root}");
    }
}

def:priv presence(healthy: any, present: any, broken: str) -> str {
    if healthy {
        return "ok";
    }
    if same(present, False) {
        return "missing";
    }
    return "unknown" if present is JsNull else broken;
}

def:priv fact(value: any, yes: str, no: str) -> str {
    return "unknown" if value is JsNull else (yes if value else no);
}

def:priv describeGit(git: any) -> str {
    if git.is_repository is JsNull {
        return "unknown";
    }
    if not git.is_repository {
        return "not detected";
    }
    return f"repository detected (commits: {fact(git.has_commits, 'yes', 'none')}, uncommitted changes: {fact(git.has_uncommitted_changes, 'yes', 'no')}, remote: {fact(git.has_remote, 'yes', 'none')})";
}

def:priv printDoctor(payload: any, result: any) {
    if len(payload.stores) == 0 {
        log("No stores registered.");
        return;
    }
    log("Store doctor");
    for store in payload.stores {
        log("");
        log(store.id);
        log(f"  Location: {store.root}");
        log(
            f"  OpenSpec root: {presence(store.openspec_root.healthy, store.openspec_root.present, 'incomplete')}",
        );
        log(f"  Metadata: {presence(store.metadata.valid, store.metadata.present, 'invalid')}");
        remoteLine = orElse(store.metadata["remote"], store.git.origin_url);
        if truthy(remoteLine) {
            log(f"  Remote: {remoteLine}");
        }
        log(f"  Git: {describeGit(store.git)}");
        if len(store.status) == 0 {
            log("  Issues: none");
            continue;
        }
        log("  Issues:");
        for status in store.status {
            log(f"    - {status.message}");
            if status["fix"] {
                log(f"      Fix: {status.fix}");
            }
        }
    }
}

async def runStoreAction(action: str, arg: any, options: any) {
    mutation = rec(store=JsNull, registry=JsNull, git=JsNull, created_files=[], status=[]);
    cleanup = rec(store=JsNull, registry=JsNull, files=JsNull, status=[]);
    listing = rec(stores=[], status=[]);
    work: any = None;
    if action == "setup" {
        work = (
            mutation,
            setupFlow(arg, options),
            toMutationOutput,
            mutationPrinter("Store ready"),
        );
    } elif action == "register" {
        work = (
            mutation,
            registerFlow(arg, options),
            toMutationOutput,
            mutationPrinter("Store registered"),
        );
    } elif action == "unregister" {
        work = (
            cleanup,
            unregisterStore(rec(id=arg)),
            toCleanupOutput,
            cleanupPrinter("Unregistered store"),
        );
    } elif action == "remove" {
        work = (
            cleanup,
            removeFlow(arg, options),
            toCleanupOutput,
            cleanupPrinter("Removed store"),
        );
    } elif action == "list" {
        options = arg;
        work = (listing, listStores(), toListOutput, printList);
    } else {
        work = (listing, doctorStores(arg), toDoctorOutput, printDoctor);
    }
    (failure, pending, convert, show) = work;
    try {
        result = await pending;
        payload = convert(result);
        if options["json"] {
            printJson(payload);
        } else {
            show(payload, result);
        }
    } except Exception as e {
        emitFailure(options["json"], failure, js_error(e), "store_error");
    }
}
