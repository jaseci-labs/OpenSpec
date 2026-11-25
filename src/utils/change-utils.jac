import from "node:path" { default as path }

glob:priv DEFAULT_SCHEMA: str = "spec-driven",
          NAME_PROBLEMS: list[tuple[str, str]] = [
              ("[A-Z]", "Change name must be lowercase (use kebab-case)"),
              ("\\s", "Change name cannot contain spaces (use hyphens instead)"),
              ("_", "Change name cannot contain underscores (use hyphens instead)"),
              ("^-", "Change name cannot start with a hyphen"),
              ("-$", "Change name cannot end with a hyphen"),
              ("--", "Change name cannot contain consecutive hyphens"),
              (
                  "[^a-z0-9-]",
                  "Change name can only contain lowercase letters, numbers, and hyphens",
              ),
          ];

def:priv invalid(error: str) -> any {
    return rec(valid=False, error=error);
}

def validateChangeName(name: any) -> any {
    if not name {
        return invalid("Change name cannot be empty");
    }
    if name.length > 200 {
        return invalid("Change name is too long (200 characters max)");
    }
    if not isKebabId(name) {
        for (pattern, error) in NAME_PROBLEMS {
            if found(name, pattern) {
                return invalid(error);
            }
        }
        return invalid(
            "Change name must follow kebab-case convention (e.g., add-auth, refactor-db)"
        );
    }
    return rec(valid=True);
}

async def createChange(projectRoot: str, name: str, options: any = None) -> any {
    validation = validateChangeName(name);
    if not validation.valid {
        raise new(globalThis.Error, validation.error);
    }
    defaultSchema = at(options, "defaultSchema") ?? DEFAULT_SCHEMA;
    schemaName = at(options, "schema");
    if not schemaName {
        try {
            schemaName = at(readProjectConfig(projectRoot), "schema") ?? defaultSchema;
        } except Exception {
            schemaName = defaultSchema;
        }
    }
    validateSchemaName(schemaName, projectRoot);
    changeDir = path.join(
        at(options, "changesDir") ?? path.join(projectRoot, "openspec", "changes"), name
    );
    if await FileSystemUtils.directoryExists(changeDir) {
        raise new(globalThis.Error, f"Change '{name}' already exists at {changeDir}");
    }
    schema = resolveSchema(schemaName, projectRoot);
    skipsSpecs = not any([isSpecsArtifactPath(a.generates) for a in schema.artifacts]);
    openspecDir = path.join(projectRoot, "openspec");
    for dir in [
        changeDir,
        path.join(openspecDir, "specs"),
        path.join(openspecDir, "changes", "archive"),
    ] {
        await FileSystemUtils.createDirectory(dir);
    }
    configPath = path.join(openspecDir, "config.yaml");
    if not await FileSystemUtils.fileExists(configPath)
        and not await FileSystemUtils.fileExists(path.join(openspecDir, "config.yml"))
    {
        await FileSystemUtils.writeFile(configPath, f"schema: {defaultSchema}\n");
    }
    writeChangeMetadata(
        changeDir,
        merge(
            rec(schema=schemaName, created=formatLocalDate()),
            rec(skip_specs=True) if skipsSpecs else None,
            at(options, "metadata"),
        ),
        projectRoot,
    );
    return rec(schema=schemaName, changeDir=changeDir);
}
