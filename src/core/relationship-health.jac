def:priv warning(code: str, message: str, fix: str) -> any {
    return makeStoreDiagnostic("warning", code, message, rec(target="relationships", fix=fix));
}

def:priv storeSection(facts: any) -> any {
    status: list[any] = [];
    remote = facts["canonicalRemote"];
    origin = facts["originUrl"];
    if truthy(remote) and truthy(origin) and remote != origin {
        status.append(
            makeStoreDiagnostic(
                "info",
                "store_remote_divergence",
                f"The store.yaml remote ({sanitizeInline(remote, 200)}) differs from the checkout's origin ({sanitizeInline(origin, 200)}).",
                rec(target="store.metadata"),
            ),
        );
    }
    drift = facts["drift"];
    if truthy(drift) and drift.behind > 0 {
        commits = f"{drift.behind} commit{'' if drift.behind == 1 else 's'}";
        status.append(
            makeStoreDiagnostic(
                "info",
                "store_checkout_drift",
                f"This store checkout has diverged from its upstream tracking branch ({drift.behind} behind, {drift.ahead} ahead); teammates on newer commits may resolve different specs."
                    if drift.ahead > 0
                    else f"This store checkout is {commits} behind its upstream tracking branch; teammates on newer commits may resolve different specs.",
                rec(target="store.git"),
            ),
        );
    }
    return merge(
        rec(
            id=facts.id,
            metadata=merge(
                rec(present=facts.metadataPresent, valid=facts.metadataValid),
                rec(remote=remote) if truthy(remote) else None,
            ),
        ),
        rec(origin_url=origin) if truthy(origin) else None,
        rec(drift=drift) if truthy(drift) else None,
        rec(status=status),
    );
}

def inspectRelationships(input: any) -> any {
    status: list[any] = [];
    if truthy(input["registryUnreadable"]) {
        status.append(
            warning(
                "relationship_registry_unreadable",
                "The store registry is unreadable; reference health cannot be checked.",
                "Run: openspec store doctor",
            ),
        );
    }
    both = input["bothShapesPointer"];
    if truthy(both) {
        status.append(
            warning(
                "root_pointer_ignored",
                f"{both.filePath} declares store '{both.value}', but this directory is a real OpenSpec root; the declaration is ignored.",
                f"Remove the store: line from {both.filePath}, or move the planning files into the store.",
            ),
        );
    }
    malformed = input["malformedPointer"];
    if truthy(malformed) {
        status.append(
            warning(
                "root_pointer_invalid",
                f"{malformed.filePath} declares a store: pointer that cannot be used ({storePointerProblem(malformed.reason)}).",
                f"Fix or remove the store: line in {malformed.filePath}.",
            ),
        );
    }
    inert = input["inertPointerDeclarations"];
    if truthy(inert) and len(inert.fields) > 0 {
        status.append(
            warning(
                "pointer_declarations_inert",
                f"{inert.filePath} declares {' and '.join(inert.fields)}, but commands read the resolved store's config — these declarations are inert.",
                f"Move the {'/'.join(inert.fields)} declarations into the store's openspec/config.yaml.",
            ),
        );
    }
    rootStatus = input["rootStatus"];
    return rec(
        root=merge(
            toRootOutput(input.root),
            rec(healthy=input.rootHealthy, status=[] if missing(rootStatus) else rootStatus),
        ),
        store=storeSection(input.storeFacts) if truthy(input["storeFacts"]) else JsNull,
        references=input.referenceEntries,
        status=status,
    );
}
