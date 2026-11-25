import from "node:path" { join }
import from "node:process" { default as process }

type DoctorOptions = any;

def:priv log(text: str) {
    globalThis.console.log(text);
}

def:priv referenceCount(config: any) -> int {
    return len(at(config, "references") ?? []);
}

async def:priv storeFacts(root_: any) -> any {
    metadata: any = JsNull;
    try {
        metadata = await readOptionalStoreMetadataState(root_.path);
    } except Exception {}
    originUrl: any = JsNull;
    drift: any = JsNull;
    if await isGitRepositoryAtRoot(root_.path) {
        (originUrl, drift) = await globalThis.Promise.all([
            promise(gitOriginUrl(root_.path)),
            promise(gitTrackingDrift(root_.path)),
        ]);
    }
    present = metadata is not JsNull;
    remote = at(metadata, "remote");
    return merge(
        rec(id=root_.storeId, metadataPresent=present, metadataValid=present),
        rec(canonicalRemote=remote) if truthy(remote) else None,
        rec(originUrl=originUrl) if truthy(originUrl) else None,
        rec(drift=drift) if truthy(drift) else None,
    );
}

async def:priv gatherHealth(root_: any) -> tuple[any, int] {
    data = await gatherRelationshipData(root_);
    input = rec(
        root=root_,
        rootHealthy=data.rootInspection.healthy,
        rootStatus=data.rootInspection.diagnostics,
        referenceEntries=data.referenceEntries,
        registryUnreadable=data.registrySnapshot.unreadable,
    );
    if truthy(root_["storeId"]) {
        input.storeFacts = await storeFacts(root_);
    }
    if root_.source == "nearest" {
        shape = classifyOpenSpecDir(root_.path);
        pointer = shape.pointer;
        if shape.hasPlanningShape and truthy(pointer.filePath) {
            if pointer["value"] is not None {
                input.bothShapesPointer = rec(value=pointer.value, filePath=pointer.filePath);
            } elif truthy(pointer["malformed"]) {
                input.malformedPointer = rec(filePath=pointer.filePath, reason=pointer.malformed);
            }
        }
    }
    if root_.source == "declared" {
        pointerRoot = findRepoPlanningRootSync(process.cwd());
        if truthy(pointerRoot) and referenceCount(readProjectConfig(pointerRoot)) > 0 {
            configPath = resolveConfigFilePath(pointerRoot);
            input.inertPointerDeclarations = rec(
                filePath=join(pointerRoot, "openspec", "config.yaml")
                    if missing(configPath)
                    else configPath,
                fields=["references"],
            );
        }
    }
    return (inspectRelationships(input), referenceCount(data.projectConfig));
}

def:priv printFindings(head: str, status: any) {
    for d in status {
        log(f"{head}{d.message}");
        if d["fix"] {
            log(f"    Fix: {d.fix}");
        }
    }
}

def:priv printHumanHealth(health: any, declared: int) {
    log("Doctor");
    log("");
    log("Root");
    log(f"  Location: {health.root.path}");
    log(f"  OpenSpec root: {'ok' if health.root.healthy else 'unhealthy'}");
    store = health.store;
    storeStatus: list[any] = [];
    if truthy(store) {
        log(
            f"  Store: {store.id} ({'metadata ok' if store.metadata.valid else 'metadata invalid'})"
        );
        storeStatus = store.status;
    }
    printFindings("  - ", [*health.root.status, *storeStatus]);
    log("");
    log("References");
    if len(health.references) == 0 {
        log(
            "  (declared references all resolve to this root)"
                if declared > 0
                else "  (none declared)",
        );
    }
    for item in health.references {
        if len(item.status) == 0 {
            where = f" ({item.root})" if truthy(item["root"]) else "";
            log(f"  - {item.store_id}: ok{where}");
        }
        printFindings(f"  - {item.store_id}: ", item.status);
    }
    for d in health.status {
        log("");
        log(f"Note: {d.message}");
        if d["fix"] {
            log(f"Fix: {d.fix}");
        }
    }
}

async def doctorCommand(options: any) {
    failure = rec(root=JsNull, store=JsNull, references=[]);
    try {
        root_ = await resolveRootForCommand(
            rec(store=options["store"], storePath=options["storePath"]),
            rec(json=options["json"], failurePayload=failure, allowImplicitRoot=False),
        );
        if not truthy(root_) {
            return;
        }
        (health, declared) = await gatherHealth(root_);
        if options["json"] {
            printJson(health);
        } else {
            printHumanHealth(health, declared);
        }
    } except Exception as e {
        emitFailure(options["json"], failure, js_error(e), "doctor_failed");
    }
}
