import from "node:child_process" { execFile }
import from "node:fs" { promises as fs }
import from "node:os" { homedir }
import from "node:path" { default as path }
import from "node:process" { default as process }
import from "node:util" { promisify }

type StoreInfo = any;
type StoreMutationResult = any;
type StoreCleanupResult = any;
type StoreListResult = any;
type StoreDoctorResult = any;
type StoreInspection = any;
type SetupStoreInput = any;

glob:priv run: any = promisify(execFile),
          UNREGISTER_FIX: str = 'Run "openspec store unregister <id>" if you only want to forget this local registry entry.',
          METADATA_FILE: str = ".openspec-store/store.yaml";

def:priv fail(message: str, code: str, target: str, fix: str) -> any {
    return StoreError(message, code, rec(target=target, fix=fix));
}

def:priv messageOf(error: any) -> str {
    return error.message
        if globalThis.Error.prototype.isPrototypeOf(error)
        else globalThis.String(error);
}

def:priv ignore(error: any) {}

async def:priv pathKind(targetPath: str) -> str {
    try {
        stat = await fs.stat(targetPath);
        return "directory" if stat.isDirectory() else ("file" if stat.isFile() else "other");
    } except Exception as e {
        err = js_error(e);
        if at(err, "code") == "ENOENT" {
            return "missing";
        }
        raise err;
    }
}

async def:priv readMetadata(storeRoot: str) -> any {
    try {
        return await readOptionalStoreMetadataState(storeRoot);
    } except Exception as e {
        raise fail(
            messageOf(js_error(e)),
            "invalid_store_metadata",
            "store.metadata",
            f"Repair {getStoreMetadataPath(storeRoot)}.",
        );
    }
}

async def:priv isGitOnlyDirectory(storeRoot: str) -> bool {
    names = await fs.readdir(storeRoot);
    return len(names) == 1 and names[0] == ".git" and await isGitRepositoryAtRoot(storeRoot);
}

def:priv alreadyRegistered(id: str) -> any {
    return makeStoreDiagnostic(
        "info",
        "store_already_registered",
        f"Store '{id}' is already registered at this path.",
        rec(target="store.registry"),
    );
}

def:priv assertNotConfigOnlyPointerRoot(storeRoot: str) {
    shape = classifyOpenSpecDir(storeRoot);
    pointer = shape.pointer;
    if shape.hasPlanningShape or pointer.filePath is JsNull {
        return;
    }
    if pointer["malformed"] {
        raise fail(
            f"The store declaration in {pointer.filePath} is invalid ({storePointerProblem(pointer.malformed)}).",
            "invalid_store_pointer",
            "store.pointer",
            f"Fix or remove the store: line in {pointer.filePath} before registering this path as a store.",
        );
    }
    if pointer["value"] is not None {
        raise fail(
            f"This repo's planning is externalized to store '{pointer.value}' ({pointer.filePath}); it is not itself a store root.",
            "store_root_pointer_declared",
            "store.pointer",
            "Register the checkout for the declared store, or remove the store: line first to convert this repo into a local store root.",
        );
    }
}

async def:priv nearestExistingDirectory(targetPath: str) -> any {
    current = path.resolve(targetPath);
    while True {
        kind_ = await pathKind(current);
        if kind_ != "missing" {
            return current if kind_ == "directory" else JsNull;
        }
        parent = path.dirname(current);
        if parent == current {
            return JsNull;
        }
        current = parent;
    }
}

def:priv isInside(parent: str, child: str) -> bool {
    relative: any = path.relative(parent, child);
    return len(relative) > 0
        and not relative.startsWith(f"..{path.sep}")
        and relative != ".."
        and not path.isAbsolute(relative);
}

async def:priv findContainingGitRepositoryRoot(storeRoot: str) -> any {
    resolved = path.resolve(storeRoot);
    nearest = await nearestExistingDirectory(path.dirname(resolved));
    if nearest is JsNull {
        return JsNull;
    }
    comparable = path.resolve(canonical(nearest), path.relative(nearest, resolved));
    def containing(gitRoot: str) -> any {
        normalizedRoot = canonical(gitRoot);
        relative: any = path.relative(normalizedRoot, comparable);
        return normalizedRoot
            if len(relative) > 0 and not relative.startsWith("..") and not path.isAbsolute(relative)
            else JsNull;
    }
    try {
        return containing(
            (
                await run("git", ["-C", nearest, "rev-parse", "--show-toplevel"], GIT_EXEC_OPTIONS)
            ).stdout.trim(),
        );
    } except Exception {
        current = nearest;
        while not await isGitRepositoryAtRoot(current) {
            parent = path.dirname(current);
            if parent == current {
                return JsNull;
            }
            current = parent;
        }
        return containing(current);
    }
}

def expandUserPath(inputPath: any) -> str {
    trimmed: any = inputPath.trim();
    if trimmed == "~" {
        return homedir();
    }
    if trimmed.startsWith("~/") or trimmed.startsWith("~\\") {
        return path.join(homedir(), trimmed.slice(2));
    }
    return trimmed;
}

def:priv requiredRoot(inputPath: any, message: str, code: str, fix: str) -> str {
    if inputPath is None or len(inputPath.trim()) == 0 {
        raise fail(message, code, "store.root", fix);
    }
    return path.resolve(expandUserPath(inputPath));
}

def:priv canonical(targetPath: str) -> str {
    return FileSystemUtils.canonicalizeExistingPath(targetPath);
}

def:priv isRegisteredAtPath(registry: any, id: str, storeRoot: str) -> bool {
    found_ = at(registry, "stores", id);
    return truthy(found_)
        and canonical(getStoreRootForBackend(found_.backend)) == canonical(storeRoot);
}

def:priv storeInfo(id: str, storeRoot: str) -> any {
    return rec(id=id, root=storeRoot, metadataPath=getStoreMetadataPath(storeRoot));
}

def:priv mutationPayload(
    id: str,
    storeRoot: str,
    git: any,
    createdFiles: any,
    registered: any,
    canonicalRemote: any,
    observedRemote: any,
) -> any {
    remotes = merge(
        rec(canonical=canonicalRemote) if truthy(canonicalRemote) else None,
        rec(observed=observedRemote) if truthy(observedRemote) else None,
    );
    return merge(
        rec(store=storeInfo(id, storeRoot)),
        rec(remotes=remotes) if len(globalThis.Object.keys(remotes)) else None,
        rec(
            registryCommit=rec(
                path=getStoreRegistryPath(),
                registered=registered.registryUpdated,
                alreadyRegistered=registered.alreadyRegistered,
            ),
            git=git,
            createdArtifacts=createdFiles,
            diagnostics=[alreadyRegistered(id)]
                if registered.alreadyRegistered and len(createdFiles) == 0
                else [],
        ),
    );
}

def:priv remoteRequiresHandEdit(id: str, storeRoot: str) -> any {
    return fail(
        f"Store '{id}' already has an identity file; --remote cannot change it.",
        "store_remote_requires_hand_edit",
        "store.metadata",
        f"Edit {getStoreMetadataPath(storeRoot)} and commit it.",
    );
}

async def:priv backendWithObservedOrigin(storeRoot: str) -> any {
    origin = await gitOriginUrl(storeRoot) if await isGitRepositoryAtRoot(storeRoot) else JsNull;
    return await resolveGitStoreBackendConfig(
        merge(rec(localPath=storeRoot), rec(remote=origin) if truthy(origin) else None),
        process.cwd(),
    );
}

def resolveSetupGitEnabled(prepared: any, initGit: any = None) -> any {
    return not isRegisteredAtPath(prepared.registry, prepared.id, prepared.root)
        if missing(initGit)
        else initGit;
}

async def prepareStoreSetup(input: any) -> any {
    id = validateStoreId("" if missing(input["id"]) else input.id);
    remote = input["remote"];
    if remote is not None and len(remote) == 0 {
        raise fail(
            "Store remote must not be empty when provided.",
            "store_remote_empty",
            "store.metadata",
            "Pass a clone URL: --remote <url>.",
        );
    }
    storeRoot = requiredRoot(
        input["path"],
        "Pass --path with the folder where this store should live.",
        "store_setup_path_required",
        f"openspec store setup {id} --path ~/openspec/{id}",
    );
    rootKind = await pathKind(storeRoot);
    if rootKind in ["file", "other"] {
        raise fail(
            f"Store setup path is not a directory: {storeRoot}",
            "store_setup_path_not_directory",
            "store.root",
            "Choose an empty directory or an existing healthy OpenSpec root.",
        );
    }
    if not (truthy(input["allowInsideGitRepository"]) or same(input["initGit"], False)) {
        gitRoot = await findContainingGitRepositoryRoot(storeRoot);
        if truthy(gitRoot) {
            raise fail(
                f"Store setup path is inside another Git repository: {gitRoot}",
                "store_setup_inside_git_repo",
                "store.root",
                "Choose a path outside that Git repository.",
            );
        }
    }
    backend: any = None;
    if rootKind == "directory" {
        assertNotConfigOnlyPointerRoot(storeRoot);
        metadata = await readMetadata(storeRoot);
        if truthy(metadata) {
            if metadata.id != id {
                raise fail(
                    f"Store metadata id '{metadata.id}' does not match requested id '{id}'.",
                    "store_metadata_id_mismatch",
                    "store.metadata",
                    f"Use id '{metadata.id}' or choose a different setup path.",
                );
            }
            if remote is not None {
                raise remoteRequiresHandEdit(id, storeRoot);
            }
        } else {
            healthy = (await inspectOpenSpecRoot(storeRoot)).healthy;
            if not healthy
                and len(await fs.readdir(storeRoot)) != 0
                and not await isGitOnlyDirectory(storeRoot)
            {
                raise fail(
                    "Store setup does not support initializing a non-empty folder that is not a healthy OpenSpec root.",
                    "store_setup_non_empty_directory",
                    "store.root",
                    "Choose an empty folder, a Git-only folder, or an existing healthy OpenSpec root.",
                );
            }
        }
        backend = await backendWithObservedOrigin(storeRoot);
    }
    registry = await readStoreRegistryState();
    assertNoRegisteredStoreConflict(
        registry, id, backend ?? rec(type="git", local_path=canonical(storeRoot))
    );
    return merge(
        rec(id=id, root=storeRoot, rootKind=rootKind, registry=registry),
        rec(backend=backend) if truthy(backend) else None,
        None if remote is None else rec(remote=remote),
    );
}

async def setupPreparedStore(prepared: any, input: any = None) -> any {
    id = prepared.id;
    storeRoot = prepared.root;
    registry = prepared.registry;
    remote = prepared["remote"];
    backend: any = prepared["backend"] if truthy(prepared["backend"]) else None;
    if prepared.rootKind == "missing" {
        exists = False;
        try {
            await fs.access(storeRoot);
            exists = True;
        } except Exception {}
        if exists {
            raise fail(
                f"The path {storeRoot} was created while setup was waiting for confirmation.",
                "store_setup_path_changed",
                "store.root",
                "Rerun openspec store setup to re-evaluate the directory.",
            );
        }
    }
    createdFiles: list[any] = [];
    createdPaths: any = [];
    gitInitialized = False;
    committed = False;
    alreadyHere = isRegisteredAtPath(registry, id, storeRoot);
    initGit = at(input, "initGit");
    gitEnabled = (not alreadyHere) if missing(initGit) else initGit;
    repoExisted = await isGitRepositoryAtRoot(storeRoot);
    if gitEnabled {
        nearest = await nearestExistingDirectory(storeRoot);
        await assertGitCommitIdentity(process.cwd() if missing(nearest) else nearest);
    }
    try {
        ensured = await ensureOpenSpecRoot(storeRoot, rec(anchorEmptyDirectories=not alreadyHere));
        createdFiles.extend(ensured.createdArtifacts);
        createdPaths = ensured.createdPaths;
        if backend is None {
            backend = await backendWithObservedOrigin(storeRoot);
        }
        assertNoRegisteredStoreConflict(registry, id, backend);
        existingMetadata = await readMetadata(storeRoot);
        if truthy(existingMetadata) and remote is not None {
            raise remoteRequiresHandEdit(id, storeRoot);
        }
        if not truthy(existingMetadata) {
            metadataDir = getStoreMetadataDir(storeRoot);
            dirMissing = await pathKind(metadataDir) == "missing";
            await writeStoreMetadataState(
                storeRoot,
                merge(rec(version=1, id=id), None if remote is None else rec(remote=remote)),
            );
            if dirMissing {
                createdPaths.push(
                    rec(relativePath=".openspec-store/", absolutePath=metadataDir, kind="directory")
                );
            }
            createdPaths.push(
                rec(
                    relativePath=METADATA_FILE,
                    absolutePath=getStoreMetadataPath(storeRoot),
                    kind="file",
                ),
            );
            createdFiles.append(METADATA_FILE);
        }
        gitInitialized = await initGitRepository(storeRoot) if gitEnabled else False;
        isRepository = gitInitialized or repoExisted;
        pathspecs = [OPENSPEC_ROOT_DIR, STORE_METADATA_DIR_NAME]
            if gitInitialized
            else [p.relativePath for p in createdPaths if p.kind == "file"];
        committed = await commitStoreFiles(storeRoot, id, pathspecs)
            if gitEnabled and isRepository
            else False;
        registered = await commitStoreRegistration(
            rec(id=id, backend=backend, writeMetadataIfMissing=False)
        );
        return mutationPayload(
            id,
            registered.storeRoot,
            rec(isRepository=isRepository, initialized=gitInitialized, committed=committed),
            createdFiles,
            registered,
            remote ?? at(existingMetadata, "remote"),
            backend["remote"],
        );
    } except Exception as e {
        if not committed {
            if len(createdPaths) > 0 {
                await rollbackCreatedPaths(createdPaths);
            }
            if gitInitialized {
                await fs.rm(path.join(storeRoot, ".git"), rec(recursive=True, force=True)).catch(
                    ignore
                );
            }
            if prepared.rootKind == "missing" {
                await fs.rmdir(storeRoot).catch(ignore);
            }
        }
        raise js_error(e);
    }
}

async def setupStore(input: any) -> any {
    return await setupPreparedStore(await prepareStoreSetup(input), rec(initGit=input["initGit"]));
}

async def registerExistingStore(input: any) -> any {
    storeRoot = requiredRoot(
        input["path"],
        "Pass a store path.",
        "store_path_required",
        "openspec store register /path/to/store",
    );
    rootKind = await pathKind(storeRoot);
    if rootKind == "missing" {
        raise fail(
            f"Store path does not exist: {storeRoot}",
            "store_path_missing",
            "store.root",
            "Clone or create the store folder before registering it.",
        );
    }
    if rootKind != "directory" {
        raise fail(
            f"Store path is not a directory: {storeRoot}",
            "store_path_not_directory",
            "store.root",
            "Pass an existing store directory.",
        );
    }
    assertNotConfigOnlyPointerRoot(storeRoot);
    openspecRoot = await inspectOpenSpecRoot(storeRoot);
    if not openspecRoot.healthy {
        problems = " ".join([d.message for d in openspecRoot.diagnostics])
            or "The OpenSpec root is missing or incomplete.";
        emptyClone = await isGitRepositoryAtRoot(storeRoot)
            and same(await gitHasCommits(storeRoot), False);
        hint = " This folder is a Git repository with no commits — if it is a clone, the origin store needs an initial commit before the clone has any files."
            if emptyClone
            else "";
        raise fail(
            f"Store register requires an existing healthy OpenSpec root. {problems}{hint}",
            "store_register_root_unhealthy",
            "openspec.root",
            "If this is a store clone: commit and push the origin store, pull it into this clone, then rerun register."
                if emptyClone
                else "Run openspec store setup for a new store, or point register at a checkout whose openspec/ files are present.",
        );
    }
    metadata = await readMetadata(storeRoot);
    explicitId: any = None if input["id"] is None else validateStoreId(input.id);
    if truthy(metadata) and explicitId is not None and metadata.id != explicitId {
        current = await readStoreRegistryState();
        elsewhere = at(current, "stores", metadata.id) is not None
            and not isRegisteredAtPath(current, metadata.id, storeRoot);
        raise fail(
            f"Store metadata id '{metadata.id}' does not match --id '{explicitId}'. The id comes from the store's committed .openspec-store/store.yaml.",
            "store_metadata_id_mismatch",
            "store.id",
            f"One checkout per store id is supported, and '{metadata.id}' is already registered. Run openspec store unregister {metadata.id} first to register this checkout instead."
                if elsewhere
                else f"Use --id {metadata.id} or register a different folder.",
        );
    }
    id = metadata.id
        if truthy(metadata)
        else (explicitId ?? validateStoreId(path.basename(storeRoot)));
    if not truthy(metadata) and not truthy(input["allowCreateIdentity"]) {
        raise fail(
            f"Turn this OpenSpec root into store '{id}'?",
            "store_register_identity_confirmation_required",
            "store.metadata",
            f"Run interactively or pass --yes to create {getStoreMetadataPath(storeRoot)}.",
        );
    }
    backend = await backendWithObservedOrigin(storeRoot);
    assertNoRegisteredStoreConflict(await readStoreRegistryState(), id, backend);
    isRepository = await isGitRepositoryAtRoot(storeRoot);
    registered = await commitStoreRegistration(
        rec(id=id, backend=backend, writeMetadataIfMissing=True)
    );
    return mutationPayload(
        id,
        registered.storeRoot,
        rec(isRepository=isRepository, initialized=False, committed=False),
        [METADATA_FILE] if registered.metadataCreated else [],
        registered,
        at(metadata, "remote"),
        backend["remote"],
    );
}

async def prepareStoreCleanup(input: any) -> any {
    found_ = await getRegisteredStore(
        rec(id=validateStoreId(input.id), globalDataDir=input["globalDataDir"])
    );
    return merge(
        storeInfo(found_.id, found_.storeRoot),
        rec(backend=found_.backend),
        rec(globalDataDir=input.globalDataDir) if truthy(input["globalDataDir"]) else None,
    );
}

def:priv cleanupResult(removed: any, target: any, files: any, diagnostics: any) -> any {
    return rec(
        store=storeInfo(removed.id, removed.storeRoot),
        registryCommit=rec(
            path=getStoreRegistryPath(rec(globalDataDir=target["globalDataDir"])), removed=True
        ),
        files=files,
        diagnostics=diagnostics,
    );
}

async def unregisterStore(input: any) -> any {
    target = await prepareStoreCleanup(input);
    removed = await unregisterStoreRegistration(
        rec(id=target.id, expectedBackend=target.backend, globalDataDir=target["globalDataDir"])
    );
    return cleanupResult(removed, target, rec(deleted=False, leftOnDisk=removed.storeRoot), []);
}

async def:priv safeToDelete(storeRoot: str, id: str) -> bool {
    rootKind = await pathKind(storeRoot);
    if rootKind == "missing" {
        return False;
    }
    if rootKind != "directory" {
        raise fail(
            f"Store path is not a directory: {storeRoot}",
            "store_remove_path_not_directory",
            "store.root",
            UNREGISTER_FIX,
        );
    }
    metadata = await readMetadata(storeRoot);
    if not truthy(metadata) {
        raise fail(
            "Store remove refuses to delete a folder without store metadata.",
            "store_remove_metadata_missing",
            "store.metadata",
            UNREGISTER_FIX,
        );
    }
    if metadata.id != id {
        raise fail(
            f"Store metadata id '{metadata.id}' does not match requested id '{id}'.",
            "store_metadata_id_mismatch",
            "store.metadata",
            "Repair the registry or run store unregister instead of deleting this folder.",
        );
    }
    return True;
}

def:priv assertNoRegisteredStoreInside(storeRoot: str, id: str, others: any) {
    root_ = canonical(storeRoot);
    nested = [o for o in others if isInside(root_, canonical(o.storeRoot))];
    if not nested {
        return;
    }
    one = len(nested) == 1;
    listed = ", ".join([f"'{o.id}' ({o.storeRoot})" for o in nested]);
    unregister = ", then ".join([f"openspec store unregister {o.id}" for o in nested]);
    raise fail(
        f"Store remove refuses to delete {storeRoot}: it contains {'another registered store' if one else 'other registered stores'}: {listed}.",
        "store_remove_contains_registered_store",
        "store.root",
        f"Unregister or remove {'that store' if one else 'those stores'} first ({unregister}), or run \"openspec store unregister {id}\" to forget '{id}' without deleting files.",
    );
}

async def removeStore(target: any) -> any {
    id = validateStoreId(target.id);
    diagnostics: list[any] = [];
    rootMissing = False;
    async def beforeCommit(item: any, remaining: any) {
        exists = await safeToDelete(item.storeRoot, id);
        rootMissing = not exists;
        if exists {
            assertNoRegisteredStoreInside(item.storeRoot, id, remaining);
        }
    }
    removed = await unregisterStoreRegistration(
        rec(
            id=id,
            expectedBackend=target.backend,
            globalDataDir=target["globalDataDir"],
            beforeCommit=beforeCommit,
        ),
    );
    deleted = False;
    if rootMissing {
        diagnostics.append(
            makeStoreDiagnostic(
                "warning",
                "store_root_missing",
                "Store files were already missing.",
                rec(target="store.root"),
            ),
        );
    } else {
        try {
            await fs.rm(removed.storeRoot, rec(recursive=True, force=True));
            deleted = True;
        } except Exception as e {
            diagnostics.append(
                makeStoreDiagnostic(
                    "warning",
                    "store_files_left_on_disk",
                    f"The registration was removed, but deleting {removed.storeRoot} failed ({js_error(e).message}).",
                    rec(
                        target="store.root", fix=f"Delete the folder manually: {removed.storeRoot}"
                    ),
                ),
            );
        }
    }
    return cleanupResult(
        removed,
        target,
        merge(rec(deleted=deleted), rec(deletedPath=removed.storeRoot) if deleted else None),
        diagnostics,
    );
}

async def listStores -> any {
    return rec(stores=[rec(id=e.id, root=e.storeRoot) for e in await listRegisteredStores()]);
}

def:priv doctorStatusForError(error: any, code: str, target: str, fix: str) -> any {
    if isinstance(error, StoreError) {
        return error.diagnostic;
    }
    return makeStoreDiagnostic("error", code, messageOf(error), rec(target=target, fix=fix));
}

async def:priv inspectStore(item: any) -> any {
    root_ = getStoreRootForBackend(item.backend);
    metadataPath = getStoreMetadataPath(root_);
    diagnostics: list[any] = [];
    rootKind = await pathKind(root_);
    metadata = rec(present=JsNull, valid=JsNull, remote=JsNull);
    git = rec(
        isRepository=JsNull,
        hasCommits=JsNull,
        hasUncommittedChanges=JsNull,
        hasRemote=JsNull,
        originUrl=JsNull,
    );
    openspecRoot = await inspectOpenSpecRoot(root_);
    if rootKind == "missing" {
        diagnostics.append(
            makeStoreDiagnostic(
                "error",
                "store_root_missing",
                "Store location does not exist.",
                rec(
                    target="store.root",
                    fix=f"Run openspec store register /path/to/{item.id} --id {item.id}.",
                ),
            ),
        );
    } elif rootKind != "directory" {
        diagnostics.append(
            makeStoreDiagnostic(
                "error",
                "store_root_not_directory",
                "Store location is not a directory.",
                rec(target="store.root", fix="Register a directory path for this store."),
            ),
        );
    } else {
        diagnostics.extend(openspecRoot.diagnostics);
        try {
            parsed = await readOptionalStoreMetadataState(root_);
            if missing(parsed) {
                metadata = rec(present=False, valid=False, remote=JsNull);
                diagnostics.append(
                    makeStoreDiagnostic(
                        "error",
                        "store_metadata_missing",
                        "Store metadata is missing.",
                        rec(
                            target="store.metadata",
                            fix=f"Create {metadataPath} or rerun store register.",
                        ),
                    ),
                );
            } elif parsed.id != item.id {
                metadata = rec(present=True, valid=False, id=parsed.id, remote=JsNull);
                diagnostics.append(
                    makeStoreDiagnostic(
                        "error",
                        "store_metadata_id_mismatch",
                        f"Store metadata id '{parsed.id}' does not match registry id '{item.id}'.",
                        rec(
                            target="store.metadata",
                            fix="Repair the local registry or store metadata so the ids match.",
                        ),
                    ),
                );
            } else {
                metadata = rec(
                    present=True,
                    valid=True,
                    id=parsed.id,
                    remote=JsNull if parsed["remote"] is None else parsed.remote,
                );
            }
        } except Exception as e {
            metadata = rec(present=True, valid=False, remote=JsNull);
            diagnostics.append(
                doctorStatusForError(
                    js_error(e),
                    "store_metadata_invalid",
                    "store.metadata",
                    f"Repair {metadataPath}.",
                ),
            );
        }
        git.isRepository = await isGitRepositoryAtRoot(root_);
        if git.isRepository {
            git.hasCommits = await gitHasCommits(root_);
            git.hasUncommittedChanges = await gitHasUncommittedChanges(root_);
            git.hasRemote = await gitHasRemote(root_);
            git.originUrl = await gitOriginUrl(root_);
            if same(git.hasCommits, False) {
                diagnostics.append(
                    makeStoreDiagnostic(
                        "warning",
                        "store_git_no_commits",
                        "Git repository has no commits yet; clones of this store will be empty until an initial commit exists.",
                        rec(
                            target="store.git",
                            fix="Commit the store files, then push to share them.",
                        ),
                    ),
                );
            } elif same(git.hasCommits, True) {
                fragile: list[str] = [];
                for relativeDir in ANCHORED_OPENSPEC_DIRS {
                    if await pathKind(path.join(root_, relativeDir)) == "directory"
                        and same(await gitDirectoryHasTrackedFiles(root_, relativeDir), False)
                    {
                        fragile.append(f"{relativeDir}/");
                    }
                }
                if fragile {
                    diagnostics.append(
                        makeStoreDiagnostic(
                            "warning",
                            "store_clone_fragile_directories",
                            f"These directories contain no tracked files and will be lost in clones: {', '.join(fragile)}.",
                            rec(
                                target="store.git",
                                fix=f"Track a file in each directory (for example {DIRECTORY_ANCHOR_FILE_NAME}) and commit it.",
                            ),
                        ),
                    );
                }
            }
        }
    }
    return rec(
        id=item.id,
        root=root_,
        metadataPath=metadataPath,
        openspecRoot=openspecRoot,
        metadata=metadata,
        git=git,
        diagnostics=diagnostics,
    );
}

async def doctorStores(id: any = None) -> any {
    selectedId: any = None if id is None else validateStoreId(id);
    registry = await readStoreRegistryState();
    entries: any = [] if missing(registry) else listStoreRegistryEntries(registry);
    selected = entries if selectedId is None else [e for e in entries if e.id == selectedId];
    if selectedId is not None and not selected {
        raise fail(
            f"Unknown store '{selectedId}'.",
            "store_not_found",
            "store.id",
            "Run openspec store list to see registered stores.",
        );
    }
    return rec(
        stores=await globalThis.Promise.all([promise(inspectStore(e)) for e in selected]),
        diagnostics=[],
    );
}

def normalizeStorePathForComparison(targetPath: str) -> str {
    return canonical(targetPath);
}
