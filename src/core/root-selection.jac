import from "node:fs" { statSync }
import from "node:path" { default as path }
import from "node:process" { default as process }

type ResolvedOpenSpecRoot = any;
type RootOutput = any;

obj RootSelectionError(globalThis.Error) {
    def init(message: str, code: str, options: any = None) {
        super.init(message);
        self.name = "RootSelectionError";
        self.diagnostic = merge(rec(severity="error", code=code, message=message), options);
    }
}

def isRootSelectionError(error: any) -> bool {
    return isinstance(error, RootSelectionError);
}

def:priv parts(target: any, fix: any) -> any {
    return merge(
        rec(target=target) if truthy(target) else None, rec(fix=fix) if truthy(fix) else None
    );
}

def:priv fromStoreError(error: any) -> any {
    err = js_error(error);
    if isinstance(err, StoreError) {
        return RootSelectionError(
            err.message, err.diagnostic.code, parts(err.diagnostic["target"], err.diagnostic["fix"])
        );
    }
    return err;
}

def:priv doctorFix(id: str) -> str {
    return f"Run openspec store doctor {id} to inspect it.";
}

def:priv makeRoot(rootPath: str, source: str, storeId: any = None) -> any {
    return merge(
        rec(
            path=rootPath,
            changesDir=path.join(rootPath, "openspec", "changes"),
            specsDir=path.join(rootPath, "openspec", "specs"),
            archiveDir=path.join(rootPath, "openspec", "changes", "archive"),
            defaultSchema="spec-driven",
            source=source,
        ),
        rec(storeId=storeId) if truthy(storeId) else None,
    );
}

def:priv canonicalDirectory(startPath: str) -> str {
    resolved = path.resolve(startPath);
    try {
        return FileSystemUtils.canonicalizeExistingPath(
            resolved if statSync(resolved).isDirectory() else path.dirname(resolved)
        );
    } except Exception {
        return resolved;
    }
}

async def:priv registryEntries(globalDataDir: any) -> any {
    registry: any = None;
    try {
        registry = await readStoreRegistryState(
            rec(globalDataDir=globalDataDir) if truthy(globalDataDir) else rec()
        );
    } except Exception as e {
        raise fromStoreError(e);
    }
    return [] if missing(registry) else listStoreRegistryEntries(registry);
}

async def:priv resolveStoreRoot(id: str, globalDataDir: any = None, source: str = "store") -> any {
    try {
        validateStoreId(id);
    } except Exception as e {
        raise fromStoreError(e);
    }
    entries = await registryEntries(globalDataDir);
    matches = [e for e in entries if e.id == id];
    if not matches {
        if not entries {
            raise RootSelectionError(
                f"Unknown store '{id}'. No stores are registered.",
                "no_registered_stores",
                rec(
                    target="store.id",
                    fix=f"Run openspec store setup {id} or openspec store register <path> first.",
                ),
            );
        }
        raise RootSelectionError(
            f"Unknown store '{id}'. Registered stores: {', '.join([e.id for e in entries])}.",
            "unknown_store",
            rec(target="store.id", fix="Pass a registered store id, or run openspec store list."),
        );
    }
    storeRoot = getStoreRootForBackend(matches[0].backend);
    inspection = await inspectRegisteredStore(id, storeRoot);
    found_ = inspection.kind;
    if found_ == "ok" {
        return makeRoot(inspection.canonicalRoot, source, id);
    }
    if found_ == "metadata_error" {
        raise fromStoreError(inspection.error);
    }
    if found_ == "unhealthy_root" {
        raise RootSelectionError(
            f"Store '{id}' does not have a healthy OpenSpec root at {storeRoot}: {inspection.problems} {doctorFix(id)}",
            "unhealthy_store_root",
            rec(target="openspec.root", fix=doctorFix(id)),
        );
    }
    message = f"Store '{id}' is missing identity metadata at {inspection.metadataPath}."
        if found_ == "metadata_missing"
        else f"Store '{id}' metadata id '{inspection.actualId}' does not match its registered id.";
    raise RootSelectionError(
        f"{message} {doctorFix(id)}",
        "store_identity_mismatch",
        rec(target="store.metadata", fix=doctorFix(id)),
    );
}

async def inspectRegisteredStore(id: str, storeRoot: str) -> any {
    metadata: any = None;
    try {
        metadata = await readOptionalStoreMetadataState(storeRoot);
    } except Exception as e {
        return rec(kind="metadata_error", error=js_error(e));
    }
    if missing(metadata) {
        return rec(kind="metadata_missing", metadataPath=getStoreMetadataPath(storeRoot));
    }
    if metadata.id != id {
        return rec(kind="metadata_id_mismatch", actualId=metadata.id);
    }
    inspection = await inspectOpenSpecRoot(storeRoot);
    if not inspection.healthy {
        return rec(
            kind="unhealthy_root",
            problems=" ".join([d.message for d in inspection.diagnostics])
                or "OpenSpec root is missing or incomplete.",
        );
    }
    return rec(kind="ok", canonicalRoot=FileSystemUtils.canonicalizeExistingPath(storeRoot));
}

def:priv findQualifyingRootSync(startPath: str) -> any {
    candidate = findRepoPlanningRootSync(startPath);
    while truthy(candidate) {
        shape = classifyOpenSpecDir(candidate);
        if shape.hasPlanningShape or truthy(shape.pointer.filePath) {
            return candidate;
        }
        parent = path.dirname(candidate);
        if parent == candidate {
            return JsNull;
        }
        candidate = findRepoPlanningRootSync(parent);
    }
    return JsNull;
}

async def:priv resolveReshaped(
    id: str, globalDataDir: any, source: str, prefix: str, reshape: any
) -> any {
    try {
        return await resolveStoreRoot(id, globalDataDir, source);
    } except Exception as e {
        err = js_error(e);
        if isinstance(err, RootSelectionError) {
            code = err.diagnostic.code;
            raise RootSelectionError(
                f"{prefix}{err.message}",
                code,
                parts(err.diagnostic["target"], reshape(code) ?? err.diagnostic["fix"]),
            );
        }
        raise err;
    }
}

async def:priv resolveNearestOrDeclaredRoot(nearestRoot: str, globalDataDir: any) -> any {
    shape = classifyOpenSpecDir(nearestRoot);
    pointer = shape.pointer;
    if shape.hasPlanningShape {
        if pointer["value"] is not None {
            globalThis.console.error(
                f"Warning: {pointer.filePath} declares store '{pointer.value}', but this directory is a real OpenSpec root; the declaration is ignored.",
            );
        }
        return makeRoot(nearestRoot, "nearest");
    }
    if truthy(pointer["malformed"]) {
        raise RootSelectionError(
            f"Invalid store declaration in {pointer.filePath}: {storePointerProblem(pointer.malformed)}.",
            "invalid_store_pointer",
            rec(
                target="store.pointer",
                fix=f"Fix the YAML syntax in {pointer.filePath}."
                    if pointer.malformed == "unparseable"
                    else f"Edit {pointer.filePath} so the store key is a registered store id, or remove it.",
            ),
        );
    }
    if pointer["value"] is None {
        return makeRoot(nearestRoot, "nearest");
    }
    return await resolveReshaped(
        pointer.value,
        globalDataDir,
        "declared",
        f"Declared in {pointer.filePath}: ",
        lambda (code: str) -> any {
            f"Register the store (openspec store register <path> --id {pointer.value}) or edit {pointer.filePath} to name a registered store."
                if code == "unknown_store"
                else None
        },
    );
}

async def:priv suggestStoreFromGitRemote(startPath: str, registeredIds: list[str]) -> any {
    url = await gitOriginUrl(canonicalDirectory(startPath));
    if not truthy(url) {
        return JsNull;
    }
    repoName = repoNameFromGitUrl(url);
    if not truthy(repoName) {
        return JsNull;
    }
    candidateId = toKebabCase(repoName);
    return candidateId
        if candidateId and isKebabId(candidateId) and candidateId in registeredIds
        else JsNull;
}

async def resolveOpenSpecRoot(options: any = None) -> any {
    globalDataDir = at(options, "globalDataDir");
    if at(options, "storePath") is not None {
        raise RootSelectionError(
            "--store-path is not supported. Register the path with openspec store register <path>, then select it with --store <id>.",
            "store_path_not_supported",
            rec(
                target="store.id",
                fix="openspec store register <path>, then rerun with --store <id>.",
            ),
        );
    }
    if at(options, "store") is not None {
        return await resolveStoreRoot(options.store, globalDataDir);
    }
    startPath = at(options, "startPath") ?? process.cwd();
    nearestRoot = findQualifyingRootSync(startPath);
    if truthy(nearestRoot) {
        return await resolveNearestOrDeclaredRoot(nearestRoot, globalDataDir);
    }
    defaultStore = getGlobalConfig()["defaultStore"];
    if truthy(defaultStore) {
        return await resolveReshaped(
            defaultStore,
            globalDataDir,
            "global_default",
            f"Global defaultStore '{defaultStore}': ",
            lambda (code: str) -> any {
                f"Register the store (openspec store register <path> --id {defaultStore}) or clear the stale global default (openspec config unset defaultStore)."
                    if code in ["unknown_store", "no_registered_stores"]
                    else None
            },
        );
    }
    registeredIds = [e.id for e in await registryEntries(globalDataDir)];
    if registeredIds {
        suggested = await suggestStoreFromGitRemote(startPath, registeredIds);
        if truthy(suggested) {
            raise RootSelectionError(
                f'No OpenSpec root found in the current directory or its ancestors. This repo\'s origin name matches the registered store "{suggested}". To use it, rerun with --store {suggested}, or add "store: {suggested}" to openspec/config.yaml so every command here uses it.',
                "no_root_with_registered_stores",
                rec(
                    target="openspec.root",
                    fix=f'Rerun with --store {suggested}, or add "store: {suggested}" to openspec/config.yaml.',
                ),
            );
        }
        listed = ", ".join(registeredIds);
        raise RootSelectionError(
            f"No OpenSpec root found in the current directory or its ancestors. Registered stores: {listed}. Pass --store <id> to use one, or run openspec init to create a local root.",
            "no_root_with_registered_stores",
            rec(
                target="openspec.root",
                fix=f"Rerun with --store <id> (registered: {listed}) or run openspec init.",
            ),
        );
    }
    if same(at(options, "allowImplicitRoot"), False) {
        raise RootSelectionError(
            "No OpenSpec root found from the current directory.",
            "no_openspec_root",
            rec(target="openspec.root", fix="Run openspec init to create a root here."),
        );
    }
    return makeRoot(canonicalDirectory(startPath), "implicit");
}

def toRootOutput(root_: any) -> any {
    return merge(
        rec(path=root_.path, source=root_.source),
        rec(store_id=root_.storeId) if truthy(root_["storeId"]) else None,
    );
}

def isStoreSelectedRoot(root_: any) -> bool {
    return root_["storeId"] is not None;
}

def findDeclaringProjectRoot(storeId: str, startPath: any = None) -> any {
    nearestRoot = findQualifyingRootSync(startPath ?? process.cwd());
    if not truthy(nearestRoot) {
        return JsNull;
    }
    shape = classifyOpenSpecDir(nearestRoot);
    if shape.hasPlanningShape or not same(shape.pointer["value"], storeId) {
        return JsNull;
    }
    return nearestRoot;
}

def emitStoreRootBanner(root_: any) {
    if isStoreSelectedRoot(root_) {
        globalThis.console.error(f"Using OpenSpec root: {root_.storeId} ({root_.path})");
    }
}

def withStoreFlag(root_: any, command: str) -> str {
    return f"{command} --store {root_.storeId}" if isStoreSelectedRoot(root_) else command;
}

def toPlanningHome(root_: any) -> any {
    return rec(
        kind="repo", root=root_.path, changesDir=root_.changesDir, defaultSchema=root_.defaultSchema
    );
}

async def resolveRootForCommand(selector: any, output: any = None) -> any {
    try {
        resolved = await resolveOpenSpecRoot(
            merge(
                None if selector["store"] is None else rec(store=selector.store),
                None if selector["storePath"] is None else rec(storePath=selector.storePath),
                None
                    if at(output, "allowImplicitRoot") is None
                    else rec(allowImplicitRoot=output.allowImplicitRoot),
            ),
        );
        if not truthy(at(output, "json")) {
            emitStoreRootBanner(resolved);
        }
        return resolved;
    } except Exception as e {
        err = js_error(e);
        if truthy(at(output, "json")) and isRootSelectionError(err) {
            globalThis.console.log(
                globalThis.JSON.stringify(
                    merge(at(output, "failurePayload"), rec(status=[err.diagnostic])), JsNull, 2
                ),
            );
            process.exitCode = 1;
            return JsNull;
        }
        raise err;
    }
}
