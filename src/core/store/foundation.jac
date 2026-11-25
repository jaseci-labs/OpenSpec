import from "node:fs" { promises as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

type StorePathOptions = any;

type StoreGitBackendConfig = any;

type StoreBackendConfig = any;

type StoreRegistryState = any;

type StoreRegistryEntry = any;

glob STORE_METADATA_DIR_NAME: str = ".openspec-store",
     STORE_METADATA_FILE_NAME: str = "store.yaml",
     STORES_DIR_NAME: str = "stores",
     STORE_REGISTRY_FILE_NAME: str = "registry.yaml";

glob:priv z: any = need("zod").z,
          yaml: any = need("yaml"),
          optionalText: any = z.string().min(1).optional(),
          RegistryStateSchema: any = z.object(
              rec(
                  version=z.literal(1),
                  stores=z.record(
                      z.string(),
                      z.object(
                          rec(
                              backend=z.object(
                                  rec(
                                      type=z.literal("git"),
                                      local_path=z.string().min(1),
                                      remote=optionalText,
                                      branch=optionalText,
                                  ),
                              ).strict(),
                          ),
                      ).strict(),
                  ),
                  repos=z.unknown().optional(),
              ),
          ).strict(),
          MetadataStateSchema: any = z.object(
              rec(version=z.literal(1), id=z.string(), remote=optionalText)
          ).strict(),
          storeRegistryLockError: any = makeLockErrorFactory(
              rec(
                  createSubject="the registry lock file",
                  busyMessage="Store registry is busy.",
                  code="store_registry_busy",
                  target="store.registry",
              ),
          );

def getStoresDir(options: any = None) -> str {
    return FileSystemUtils.joinPath(
        at(options, "globalDataDir") ?? getGlobalDataDir(), STORES_DIR_NAME
    );
}

def getStoreRegistryPath(options: any = None) -> str {
    return FileSystemUtils.joinPath(getStoresDir(options), STORE_REGISTRY_FILE_NAME);
}

def getStoreMetadataDir(storeRoot: str) -> str {
    return FileSystemUtils.joinPath(storeRoot, STORE_METADATA_DIR_NAME);
}

def getStoreMetadataPath(storeRoot: str) -> str {
    return FileSystemUtils.joinPath(getStoreMetadataDir(storeRoot), STORE_METADATA_FILE_NAME);
}

def validateStoreId(id: str) -> str {
    problem = folderStyleNameProblem(id, "Store id");
    if problem is not JsNull or not isKebabId(id) {
        raise StoreError(
            f"Store id {KEBAB_ID_DESCRIPTION}" if problem is JsNull else problem,
            "invalid_store_id",
            rec(target="store.id", fix=KEBAB_ID_FIX),
        );
    }
    return id;
}

def isValidStoreId(id: str) -> bool {
    try {
        validateStoreId(id);
        return True;
    } except Exception {
        return False;
    }
}

def:priv invalidState(label: str, message: str) -> any {
    diagnostic = rec(
        code="invalid_store_metadata",
        target="store.metadata",
        fix="Repair .openspec-store/store.yaml.",
    )
        if "metadata" in label
        else rec(
            code="invalid_store_registry",
            target="store.registry",
            fix=f"Repair or remove {getStoreRegistryPath(rec())}.",
        );
    return StoreError(
        f"Invalid {label}: {message}",
        diagnostic.code,
        rec(target=diagnostic.target, fix=diagnostic.fix),
    );
}

def:priv checked(schema: any, raw: any, label: str) -> any {
    result = schema.safeParse(raw);
    if not result.success {
        raise invalidState(label, formatZodIssues(result.error));
    }
    if label == "store registry state" {
        for id in globalThis.Object.keys(result.data.stores) {
            if not isKebabId(id) {
                raise invalidState("store id", f"'{id}': {KEBAB_ID_DESCRIPTION}");
            }
        }
        return rec(version=1, stores=result.data.stores);
    }
    validateStoreId(result.data.id);
    remote = result.data["remote"];
    return merge(rec(version=1, id=result.data.id), None if remote is None else rec(remote=remote));
}

def:priv parsed(schema: any, content: str, label: str) -> any {
    raw: any = None;
    try {
        raw = yaml.parse(content);
    } except Exception as e {
        error = js_error(e);
        raise invalidState(
            label,
            error.message if isinstance(error, globalThis.Error) else globalThis.String(error),
        );
    }
    return checked(schema, raw, label);
}

def parseStoreRegistryState(content: str) -> any {
    return parsed(RegistryStateSchema, content, "store registry state");
}

def parseStoreMetadataState(content: str) -> any {
    return parsed(MetadataStateSchema, content, "store metadata state");
}

def serializeStoreRegistryState(state: any) -> str {
    return yaml.stringify(checked(RegistryStateSchema, state, "store registry state"));
}

def serializeStoreMetadataState(state: any) -> str {
    return yaml.stringify(checked(MetadataStateSchema, state, "store metadata state"));
}

def listStoreRegistryEntries(registry: any) -> any {
    return globalThis.Array.prototype.sort.call(
        [
            rec(id=id, backend=store.backend)
            for (id, store) in globalThis.Object.entries(registry.stores)
        ],
        lambda (a: any, b: any) -> any { a.id.localeCompare(b.id) },
    );
}

async def isStoreRoot(candidateRoot: str) -> bool {
    return await pathIsFile(getStoreMetadataPath(candidateRoot));
}

async def readStoreRegistryState(options: any = None) -> any {
    registryPath = getStoreRegistryPath(options);
    if not await pathIsFile(registryPath) {
        return JsNull;
    }
    return parseStoreRegistryState(await fs.readFile(registryPath, "utf-8"));
}

async def writeStoreRegistryState(state: any, options: any = None) {
    await writeFileAtomically(getStoreRegistryPath(options), serializeStoreRegistryState(state));
}

async def updateStoreRegistryState(updater: any, options: any = None) -> any {
    lockPath = f"{getStoreRegistryPath(options)}.lock";
    lock = await acquireFileLock(rec(lockPath=lockPath, errorFor=storeRegistryLockError));
    try {
        next = await globalThis.Promise.resolve(updater(await readStoreRegistryState(options)));
        await writeStoreRegistryState(next, options);
        return next;
    } finally {
        await releaseFileLock(lock, lockPath);
    }
}

async def readStoreMetadataState(storeRoot: str) -> any {
    return parseStoreMetadataState(await fs.readFile(getStoreMetadataPath(storeRoot), "utf-8"));
}

async def readOptionalStoreMetadataState(storeRoot: str) -> any {
    try {
        return await readStoreMetadataState(storeRoot);
    } except Exception as e {
        if isNodeErrorCode(js_error(e), "ENOENT") {
            return JsNull;
        }
        raise;
    }
}

async def writeStoreMetadataState(storeRoot: str, state: any) {
    await FileSystemUtils.writeFile(
        getStoreMetadataPath(storeRoot), serializeStoreMetadataState(state)
    );
}

async def resolveGitStoreBackendConfig(input: any, cwd: any = None) -> any {
    cwd = cwd ?? process.cwd();
    localPath: any = input.localPath;
    if len(localPath) == 0 {
        raise new(globalThis.Error, "Store local path must not be empty.");
    }
    resolvedPath = path.resolve(localPath)
        if path.isAbsolute(localPath)
        else path.resolve(cwd, localPath);
    if not await pathIsDirectory(resolvedPath) {
        raise new(globalThis.Error, f"Store local path does not exist: {localPath}");
    }
    if input["remote"] is not None and len(input.remote) == 0 {
        raise new(globalThis.Error, "Store backend remote must not be empty when provided.");
    }
    if input["branch"] is not None and len(input.branch) == 0 {
        raise new(globalThis.Error, "Store branch must not be empty when provided.");
    }
    return merge(
        rec(type="git", local_path=FileSystemUtils.canonicalizeExistingPath(resolvedPath)),
        rec(remote=input.remote) if truthy(input["remote"]) else None,
        rec(branch=input.branch) if truthy(input["branch"]) else None,
    );
}
