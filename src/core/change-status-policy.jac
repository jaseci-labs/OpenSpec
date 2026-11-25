type PlanningHomeSummary = any;

type ActionContext = any;

type ChangeNextStepsInput = any;

type ChangeStatusPolicyArtifact = any;

def summarizePlanningHome(planningHome: any = None) -> any {
    if not truthy(planningHome) {
        return None;
    }
    return globalThis.Object.fromEntries([
        [k, planningHome[k]]
        for k in ["kind", "root", "changesDir", "defaultSchema"]
    ]);
}

def buildActionContext(ctx: any) -> any {
    store = ctx["store"];
    home = ctx.projectRoot;
    roots = [home];
    constraint = "Repo-local change artifacts and implementation edits are scoped to this project.";
    if truthy(store) {
        planning = f"Change artifacts live in store '{store.id}' ({home}).";
        target = store["implementationRoot"];
        if target {
            roots = [target, home];
            constraint = f"{planning} Implementation edits go in {target}, the project on the current path that declares this store; ask the user before editing any other repository.";
        } else {
            constraint = f"{planning} OpenSpec could not determine which repository implements this change; ask the user which repository to edit, and make implementation edits there.";
        }
    }
    return rec(
        mode="repo-local",
        sourceOfTruth="repo",
        planningArtifacts=ctx.artifactIds,
        linkedContext=[],
        allowedEditRoots=roots,
        requiresAffectedAreaSelection=False,
        constraints=[constraint],
    );
}

def resolveNextStep(change: any) -> any {
    ready = [a for a in change.artifactStatuses if a["status"] == "ready"];
    if not ready and not change["allArtifactsComplete"] {
        return None;
    }
    flag = f" --store {change['storeId']}" if change["storeId"] else "";
    command = f"openspec instructions {ready[0].id if ready else 'apply'} --change \"{change.changeName}\"{flag} --json";
    return rec(
        command=command,
        sentence=f"Run {command} before writing that artifact."
            if ready
            else f"All planning artifacts are complete. Run {command} to inspect implementation progress.",
    );
}

def buildNextSteps(change: any) -> list[str] {
    step = resolveNextStep(change);
    return [] if step is None else [step.sentence];
}
