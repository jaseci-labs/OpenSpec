import from "node:fs" { promises as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

type RegistrySnapshot = any;

def getStoreRootForBackend(backend: any) -> any {
    return backend.local_path if backend.type == "git" else None;
}

def:priv normalized(targetPath: str) -> str {
    try {
        return FileSystemUtils.canonicalizeExistingPath(targetPath);
    } except Exception {
        return path.resolve(targetPath);
    }
}

def:priv notFound(id: str) -> any {
    return StoreError(
        f"Unknown store '{id}'",
        "store_not_found",
        rec(target="store.id", fix="Run openspec store list to see registered stores."),
    );
}

def:priv withRoot(item: any) -> any {
    return merge(item, rec(storeRoot=getStoreRootForBackend(item.backend)));
}

def:priv sortedState(stores: any) -> any {
    entries = globalThis.Array.prototype.sort.call(
        globalThis.Object.entries(stores),
        lambda (a: any, b: any) -> any { a[0].localeCompare(b[0]) },
    );
    return rec(version=1, stores=globalThis.Object.fromEntries(entries));
}

def assertNoRegisteredStoreConflict(registry: any, id: str, backend: any) {
    nextPath = normalized(getStoreRootForBackend(backend));
    for item in listStoreRegistryEntries(
        rec(version=1, stores=rec()) if missing(registry) else registry
    ) {
        entryRoot = getStoreRootForBackend(item.backend);
        samePath = normalized(entryRoot) == nextPath;
        if item.id == id and not samePath {
            raise StoreError(
                f"Store '{id}' is already registered at {entryRoot}. One checkout per store id is supported on this machine.",
                "store_id_conflict",
                rec(
                    target="store.id",
                    fix=f"Use the existing registration, or run openspec store unregister {id} first to switch this id to a different checkout.",
                ),
            );
        }
        if item.id != id and samePath {
            raise StoreError(
                f"Store path is already registered as '{item.id}'.",
                "store_path_conflict",
                rec(
                    target="store.root",
                    fix=f"Use the existing '{item.id}' registration or choose a different path.",
                ),
            );
        }
    }
}

def:priv registeredOrThrow(registry: any, id: str) -> any {
    item = at(registry, "stores", id);
    if not truthy(item) {
        raise notFound(id);
    }
    return rec(id=id, backend=item.backend);
}

def:priv sameCheckout(actual: any, expected: any) -> bool {
    return actual.type == expected.type
        and normalized(actual.local_path) == normalized(expected.local_path)
        and same(actual["branch"], expected["branch"]);
}

def:priv backendsMatch(actual: any, expected: any) -> bool {
    return sameCheckout(actual, expected) and same(actual["remote"], expected["remote"]);
}

def:priv assertExpectedBackend(id: str, actual: any, expected: any) {
    if truthy(expected) and not backendsMatch(actual, expected) {
        raise StoreError(
            f"Store '{id}' changed before cleanup completed.",
            "store_registry_changed",
            rec(
                target="store.registry",
                fix="Retry the cleanup command after reviewing the current store registration.",
            ),
        );
    }
}

async def:priv ensureStoreMetadata(storeRoot: str, id: str, writeIfMissing: bool) -> bool {
    metadata = await readOptionalStoreMetadataState(storeRoot);
    if missing(metadata) {
        if not writeIfMissing {
            metadataPath = getStoreMetadataPath(storeRoot);
            raise StoreError(
                f"Registered store '{id}' is missing metadata at {metadataPath}",
                "store_metadata_missing",
                rec(
                    target="store.metadata",
                    fix=f'Create {metadataPath} or rerun "openspec store register <path>".',
                ),
            );
        }
        await writeStoreMetadataState(storeRoot, rec(version=1, id=id));
        return True;
    }
    if metadata.id != id {
        raise StoreError(
            f"Store metadata id '{metadata.id}' does not match registered id '{id}'",
            "store_metadata_id_mismatch",
            rec(
                target="store.metadata",
                fix="Repair the local registry or store metadata so the ids match.",
            ),
        );
    }
    return False;
}

async def commitStoreRegistration(input: any) -> any {
    id = validateStoreId(input.id);
    backend = input.backend;
    storeRoot = getStoreRootForBackend(backend);
    scope = rec(globalDataDir=input["globalDataDir"]);
    metadataCreated = False;
    isRerun = False;
    registryUpdated = False;
    try {
        metadataCreated = await ensureStoreMetadata(
            storeRoot, id, truthy(input["writeMetadataIfMissing"])
        );
        existing = at(await readStoreRegistryState(scope), "stores", id, "backend");
        isRerun = existing is not None and sameCheckout(existing, backend);
        if not (isRerun and backendsMatch(existing, backend)) {
            await updateStoreRegistryState(
                lambda (registry: any) -> any {
                    assertNoRegisteredStoreConflict(registry, id, backend);
                    return sortedState(
                        merge(
                            at(registry, "stores"),
                            globalThis.Object.fromEntries([[id, rec(backend=backend)]]),
                        ),
                    );
                },
                scope,
            );
            registryUpdated = True;
        }
    } except Exception as e {
        if metadataCreated {
            current: any = JsNull;
            try {
                current = await readStoreRegistryState(scope);
            } except Exception {}
            if not truthy(at(current, "stores", id)) {
                await fs.rm(getStoreMetadataPath(storeRoot), rec(force=True));
                await fs.rmdir(getStoreMetadataDir(storeRoot)).catch(
                    lambda (ignored: any) -> any { None }
                );
            }
        }
        raise js_error(e);
    }
    return rec(
        id=id,
        storeRoot=storeRoot,
        backend=backend,
        metadataCreated=metadataCreated,
        registryUpdated=registryUpdated,
        alreadyRegistered=isRerun,
    );
}

async def registerStore(input: any) -> any {
    id = validateStoreId(input.id);
    backend = await resolveGitStoreBackendConfig(
        merge(
            rec(localPath=input.localPath),
            None if input["remote"] is None else rec(remote=input.remote),
            None if input["branch"] is None else rec(branch=input.branch),
        ),
        input["cwd"] ?? process.cwd(),
    );
    committed = await commitStoreRegistration(
        merge(
            rec(id=id, backend=backend, writeMetadataIfMissing=True),
            rec(globalDataDir=input.globalDataDir) if truthy(input["globalDataDir"]) else None,
        ),
    );
    return rec(id=committed.id, storeRoot=committed.storeRoot, backend=committed.backend);
}

async def readRegistrySnapshot(options: any = None) -> any {
    try {
        registry = await readStoreRegistryState(options);
        return rec(
            entries=[] if missing(registry) else listStoreRegistryEntries(registry),
            unreadable=False,
        );
    } except Exception {
        return rec(entries=JsNull, unreadable=True);
    }
}

async def listRegisteredStores(options: any = None) -> any {
    registry = await readStoreRegistryState(options);
    return [] if missing(registry) else [withRoot(e) for e in listStoreRegistryEntries(registry)];
}

async def getRegisteredStore(input: any) -> any {
    id = validateStoreId(input.id);
    item = registeredOrThrow(
        await readStoreRegistryState(rec(globalDataDir=input["globalDataDir"])), id
    );
    assertExpectedBackend(id, item.backend, input["expectedBackend"]);
    return withRoot(item);
}

async def unregisterStoreRegistration(input: any) -> any {
    id = validateStoreId(input.id);
    removed: any = None;
    async def update(registry: any) -> any {
        item = registeredOrThrow(registry, id);
        assertExpectedBackend(id, item.backend, input["expectedBackend"]);
        stores = merge(at(registry, "stores"));
        globalThis.Reflect.deleteProperty(stores, id);
        next = sortedState(stores);
        if input["beforeCommit"] {
            await globalThis.Promise.resolve(
                input.beforeCommit(
                    withRoot(item), [withRoot(e) for e in listStoreRegistryEntries(next)]
                ),
            );
        }
        removed = item;
        return next;
    }
    await updateStoreRegistryState(update, rec(globalDataDir=input["globalDataDir"]));
    if removed is None {
        raise notFound(id);
    }
    return withRoot(removed);
}

async def resolveRegisteredStore(input: any) -> any {
    id = validateStoreId(input.id);
    registry = await readStoreRegistryState(rec(globalDataDir=input["globalDataDir"]));
    if missing(registry) {
        raise StoreError(
            "No store registry found",
            "no_store_registry",
            rec(
                target="store.id",
                fix="Register a store with openspec store register <path>, then select it with --store <id>.",
            ),
        );
    }
    backend = registeredOrThrow(registry, id).backend;
    storeRoot = getStoreRootForBackend(backend);
    await ensureStoreMetadata(storeRoot, id, False);
    return rec(id=id, storeRoot=storeRoot, backend=backend);
}
