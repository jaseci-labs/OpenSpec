import from "node:fs" { default as fs }
import from "node:path" { default as path }

type SchemaInfo = any;

obj SchemaLoadError(globalThis.Error) {
    def init(message: str, schemaPath: str, cause: any = None) {
        super.init(message);
        self.schemaPath = schemaPath;
        self.cause = cause;
        self.name = "SchemaLoadError";
    }
}

glob:priv packageSchemasDirOverride: any = None;

def setPackageSchemasDir(resolveDir: any) {
    packageSchemasDirOverride = resolveDir;
}

def getPackageSchemasDir -> str {
    if packageSchemasDirOverride {
        return packageSchemasDirOverride();
    }
    return path.join(packageRoot(), "schemas");
}

def getUserSchemasDir -> str {
    return path.join(getGlobalDataDir(), "schemas");
}

def getProjectSchemasDir(projectRoot: str) -> str {
    return path.join(projectRoot, "openspec", "schemas");
}

def isSchemaDir(parentDir: str, dirent: any) -> bool {
    name: str = dirent.name;
    if name.startswith(".fork-staging-")
        or ".fork-backup-" in name
        or name.startswith(".init-staging-")
        or ".init-backup-" in name
    {
        return False;
    }
    if dirent.isDirectory() {
        return True;
    }
    if dirent.isSymbolicLink() {
        try {
            return fs.statSync(path.join(parentDir, name)).isDirectory();
        } except Exception {
            return False;
        }
    }
    return False;
}

def:priv getSchemaCandidateDir(schemasDir: str, name: str) -> any {
    schemaDir = path.join(schemasDir, name);
    schemaPath = path.join(schemaDir, "schema.yaml");
    if not fs.existsSync(schemaPath) {
        return None;
    }
    try {
        FileSystemUtils.assertPathWithin(schemaDir, schemaPath);
        return schemaDir;
    } except Exception {
        return None;
    }
}

def getSchemaDir(name: str, projectRoot: any = None) -> any {
    if name in ["", ".", ".."]
        or found(name, "[\\\\/]", "u")
        or found(name, "^[A-Za-z]:", "u")
        or path.posix.isAbsolute(name)
        or path.win32.isAbsolute(name)
    {
        return JsNull;
    }
    roots = ([getProjectSchemasDir(projectRoot)] if projectRoot else []) + [
        getUserSchemasDir(),
        getPackageSchemasDir(),
    ];
    for dir in roots {
        candidate = getSchemaCandidateDir(dir, name);
        if candidate {
            return candidate;
        }
    }
    return JsNull;
}

def:priv asError(err: any) -> any {
    return err
        if globalThis.Error.prototype.isPrototypeOf(err)
        else new(globalThis.Error, globalThis.String(err));
}

def resolveSchema(name: str, projectRoot: any = None) -> any {
    normalizedName = sub(name, "\\.ya?ml$", "", "");
    schemaDir = getSchemaDir(normalizedName, projectRoot);
    if not schemaDir {
        raise new(
            globalThis.Error,
            f"Schema '{normalizedName}' not found. Available schemas: {', '.join(listSchemas(projectRoot))}",
        );
    }
    schemaPath = path.join(schemaDir, "schema.yaml");
    content = "";
    try {
        content = fs.readFileSync(schemaPath, "utf-8");
    } except Exception as e {
        ioError = asError(js_error(e));
        raise SchemaLoadError(
            f"Failed to read schema at '{schemaPath}': {ioError.message}", schemaPath, ioError
        );
    }
    try {
        return parseSchema(content);
    } except Exception as e {
        err = asError(js_error(e));
        prefix = "Invalid schema"
            if err.name == "SchemaValidationError"
            else "Failed to parse schema";
        raise SchemaLoadError(f"{prefix} at '{schemaPath}': {err.message}", schemaPath, err);
    }
}

def:priv schemaEntries(schemasDir: str) -> list[str] {
    if not fs.existsSync(schemasDir) {
        return [];
    }
    return [
        d.name
        for d in fs.readdirSync(schemasDir, rec(withFileTypes=True))
        if isSchemaDir(schemasDir, d)
            and fs.existsSync(path.join(schemasDir, d.name, "schema.yaml"))
    ];
}

def listSchemas(projectRoot: any = None) -> list[str] {
    dirs = [getPackageSchemasDir(), getUserSchemasDir()]
        + ([getProjectSchemasDir(projectRoot)] if projectRoot else []);
    return sorted(set([n for d in dirs for n in schemaEntries(d)]));
}

def listSchemasWithInfo(projectRoot: any = None) -> any {
    schemas: list[any] = [];
    seen: set[str] = set();
    sources = ([(getProjectSchemasDir(projectRoot), "project")] if projectRoot else []) + [
        (getUserSchemasDir(), "user"),
        (getPackageSchemasDir(), "package"),
    ];
    for (schemasDir, source) in sources {
        for name in schemaEntries(schemasDir) {
            if name in seen {
                continue;
            }
            try {
                schema = parseSchema(
                    fs.readFileSync(path.join(schemasDir, name, "schema.yaml"), "utf-8")
                );
                schemas.append(
                    rec(
                        name=name,
                        description=schema["description"] or "",
                        artifacts=[a.id for a in schema.artifacts],
                        source=source,
                    ),
                );
                if source != "package" {
                    seen.add(name);
                }
            } except Exception {}
        }
    }
    return globalThis.Array.prototype.sort.call(
        schemas, lambda (a: any, b: any) -> int { a.name.localeCompare(b.name) }
    );
}
