glob:priv KEY: str = "skillsScope";

def keepsProjectSkills(projectPath: str) -> bool {
    return at(readProjectConfig(projectPath), KEY) == "project";
}

async def:priv readDocument(projectPath: str, configPath: str) -> any {
    FileSystemUtils.assertProjectArtifactPath(projectPath, configPath);
    return need("yaml").parseDocument(await FileSystemUtils.readFile(configPath));
}

async def rememberProjectSkills(projectPath: str) -> any {
    configPath = resolveConfigFilePath(projectPath);
    if configPath is JsNull {
        file = FileSystemUtils.resolveProjectArtifactPath(projectPath, "openspec/config.yaml");
        await FileSystemUtils.writeFile(file, f"schema: spec-driven\n{KEY}: project\n");
        return file;
    }
    doc = await readDocument(projectPath, configPath);
    if len(doc.errors) or (doc.contents is not JsNull and not need("yaml").isMap(doc.contents)) {
        return None;
    }
    doc.set(KEY, "project");
    await FileSystemUtils.writeFile(configPath, doc.toString());
    return configPath;
}

async def forgetProjectSkills(projectPath: str) {
    configPath = resolveConfigFilePath(projectPath);
    if configPath is JsNull {
        return;
    }
    doc = await readDocument(projectPath, configPath);
    if len(doc.errors) or not need("yaml").isMap(doc.contents) or not doc.has(KEY) {
        return;
    }
    doc.delete(KEY);
    await FileSystemUtils.writeFile(configPath, doc.toString());
}
