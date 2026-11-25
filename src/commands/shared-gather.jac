import from "node:path" { join }

async def gatherRelationshipData(root_: any) -> any {
    registrySnapshot = await readRegistrySnapshot();
    projectConfig = readProjectConfig(root_.path);
    configPath = resolveConfigFilePath(root_.path);
    references = at(projectConfig, "references");
    referenceEntries = await assembleReferenceIndex(
        rec(
            references=[] if missing(references) else references,
            resolvedRoot=root_,
            includeSpecs=False,
            registryEntries=registrySnapshot.entries,
        ),
    );
    return rec(
        registrySnapshot=registrySnapshot,
        projectConfig=projectConfig,
        storeConfigPath=join(root_.path, "openspec", "config.yaml")
            if missing(configPath)
            else configPath,
        referenceEntries=referenceEntries,
        rootInspection=await inspectOpenSpecRoot(root_.path),
    );
}
