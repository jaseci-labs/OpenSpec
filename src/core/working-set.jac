type WorkingSet = any;
type WorkingSetMember = any;

def isAvailableMember(member: any) -> bool {
    return member["path"] is not None and len(member.status) == 0;
}

def assembleWorkingSet(input: any) -> any {
    members = [
        merge(
            rec(role="referenced_store", id=e.store_id),
            None if e["root"] is None else rec(path=e.root),
            rec(fetch=fetchRecipe(e.store_id))
                if e["root"] is not None and len(e.status) == 0
                else None,
            rec(status=e.status),
        )
        for e in input.referenceEntries
    ];
    topLevel = input["topLevelStatus"];
    return rec(
        root=merge(toRootOutput(input.root), rec(role="openspec_root")),
        members=members,
        status=[
            d
            for d in ([] if topLevel is None else topLevel)
            if d.code == "relationship_registry_unreadable"
        ],
    );
}

def buildCodeWorkspaceJson(workingSet: any, rootName: str) -> str {
    folders = [rec(name=rootName, path=workingSet.root.path)];
    folders.extend([
        rec(name=f"ref:{m.id}", path=m.path)
        for m in workingSet.members
        if isAvailableMember(m)
    ]);
    return globalThis.JSON.stringify(rec(folders=folders), None, 2) + "\n";
}
