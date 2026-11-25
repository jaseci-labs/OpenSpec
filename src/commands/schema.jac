import from "node:fs" {
    chmodSync,
    copyFileSync,
    existsSync,
    lstatSync,
    mkdirSync,
    mkdtempSync,
    readdirSync,
    readFileSync,
    readlinkSync,
    realpathSync,
    renameSync,
    rmSync,
    statSync,
    writeFileSync,
}
import from "node:path" { basename, dirname, join, resolve }
import from "node:crypto" { createHash }
import from "node:process" { default as process }

glob schemaInitFileOperations: any = rec(renameSync=renameSync);

glob:priv DEFAULT_ARTIFACTS: list[tuple[str, str, str, str]] = [
              (
                  "proposal",
                  "High-level description of the change, its motivation, and scope",
                  "proposal.md",
                  "proposal.md",
              ),
              (
                  "specs",
                  "Detailed specifications with requirements and scenarios",
                  "specs/**/*.md",
                  "specs/spec.md",
              ),
              (
                  "design",
                  "Technical design decisions and implementation approach",
                  "design.md",
                  "design.md",
              ),
              ("tasks", "Implementation checklist with trackable tasks", "tasks.md", "tasks.md"),
          ],
          ARTIFACT_IDS: list[str] = [a[0] for a in DEFAULT_ARTIFACTS],
          INIT_EXISTS_HINT: str = 'Use --force to overwrite or "openspec schema fork" to copy',
          KEBAB_HINT: str = "Schema names must be kebab-case (e.g., my-workflow)";

glob:priv TEMPLATES: dict[str, str] = {"proposal": """# Proposal

## Why

<!-- Describe the motivation for this change -->

## What Changes

<!-- Describe what will change -->

## Capabilities

### New Capabilities
<!-- List new capabilities -->

### Modified Capabilities
<!-- List modified capabilities -->

## Impact

<!-- Describe the impact on existing functionality -->
""", "specs": """# Spec Delta

## ADDED Requirements

### Requirement: Example requirement

Description of the requirement.

#### Scenario: Example scenario
- **WHEN** some condition
- **THEN** some outcome
""", "design": """# Design

## Context

<!-- Background and context -->

## Goals / Non-Goals

**Goals:**
<!-- List goals -->

**Non-Goals:**
<!-- List non-goals -->

## Decisions

### 1. Decision Name

Description and rationale.

**Alternatives considered:**
- Alternative 1: Rejected because...

## Risks / Trade-offs

<!-- List risks and trade-offs -->
""", "tasks": """# Tasks

## Implementation Tasks

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3
"""};

def:priv emit(payload: any) {
    globalThis.console.log(globalThis.JSON.stringify(payload, JsNull, 2));
}

def:priv fail(json: any, payload: any, lines: list[str]) {
    if json {
        emit(payload);
    } else {
        for line in lines {
            globalThis.console.error(line);
        }
    }
    process.exitCode = 1;
}

def:priv failWith(json: any, e: any, key: str) {
    message = js_error(e).message;
    fail(
        json,
        globalThis.Object.fromEntries([[key, False], ["error", message]]),
        [f"Error: {message}"],
    );
}

def:priv notFound(json: any, name: str, projectRoot: str, flag: any) {
    available = listSchemas(projectRoot);
    error = f"Schema '{name}' not found";
    payload = rec(error=error, available=available);
    if flag is not None {
        payload = globalThis.Object.fromEntries([
            [flag, False],
            ["error", error],
            ["available", available],
        ]);
    }
    fail(json, payload, [f"Error: {error}", f"Available schemas: {', '.join(available)}"]);
}

def:priv getSchemaResolution(name: str, projectRoot: str) -> any {
    found_ = [
        rec(source=source, path=folder)
        for (source, folder) in [
            ("project", join(getProjectSchemasDir(projectRoot), name)),
            ("user", join(getUserSchemasDir(), name)),
            ("package", join(getPackageSchemasDir(), name)),
        ]
        if existsSync(join(folder, "schema.yaml"))
    ];
    if not found_ {
        return None;
    }
    return rec(name=name, source=found_[0].source, path=found_[0].path, shadows=found_[1:]);
}

def:priv validateSchema(schemaDir: str, verbose: any = False) -> any {
    issues: list[any] = [];
    def step(text: str) {
        if verbose {
            globalThis.console.log(f"  {text}");
        }
    }
    def broken(message: str) -> any {
        issues.append(rec(level="error", path="schema.yaml", message=message));
        return rec(valid=False, issues=issues);
    }
    schemaPath = join(schemaDir, "schema.yaml");
    step("Checking schema.yaml exists...");
    if not existsSync(schemaPath) {
        return broken("schema.yaml not found");
    }
    step("Parsing YAML...");
    content: any = None;
    try {
        content = readFileSync(schemaPath, "utf-8");
    } except Exception as e {
        return broken(f"Failed to read file: {js_error(e).message}");
    }
    step("Validating schema structure...");
    schema: any = None;
    try {
        schema = parseSchema(content);
    } except Exception as e {
        err = js_error(e);
        return broken(
            err.message if isinstance(err, SchemaValidationError) else f"Parse error: {err.message}"
        );
    }
    step("Checking template files...");
    templatesDir = join(schemaDir, "templates");
    for artifact in schema.artifacts {
        templatePath = join(templatesDir, artifact.template);
        problem: any = None;
        if not existsSync(templatePath) {
            problem = f"Template file '{artifact.template}' not found for artifact '{artifact.id}'";
        } else {
            try {
                FileSystemUtils.assertPathWithin(templatesDir, templatePath);
            } except Exception {
                problem = f"Template file '{artifact.template}' points outside the schema templates directory";
            }
        }
        if problem is not None {
            issues.append(
                rec(level="error", path=f"artifacts.{artifact.id}.template", message=problem)
            );
        }
    }
    step("Dependency graph validation passed (via parseSchema)");
    warning = findApplyTracksWarning(schema);
    if warning {
        issues.append(rec(level="warning", path="apply.tracks", message=warning));
    }
    return rec(valid=not any([i.level == "error" for i in issues]), issues=issues);
}

def:priv isValidSchemaName(name: str) -> bool {
    return found(name, "^[a-z][a-z0-9]*(-[a-z0-9]+)*$");
}

def:priv resolveSchemaCopyPath(allowedRoot: str, sourcePath: str) -> str {
    try {
        canonicalPath = realpathSync(sourcePath);
        FileSystemUtils.assertPathWithin(realpathSync(allowedRoot), canonicalPath);
        return canonicalPath;
    } except Exception as e {
        error = js_error(e);
        detail = error.message
            if globalThis.Error.prototype.isPrototypeOf(error)
            else globalThis.String(error);
        raise new(
            globalThis.Error,
            f"Cannot fork schema with linked or unsupported entry: {sourcePath}: {detail}",
            rec(cause=error),
        );
    }
}

def:priv walkSchemaTree(src: str, dest: any, allowedRoot: str, ancestors: set[str]) {
    canonicalSrc = resolveSchemaCopyPath(allowedRoot, src);
    if canonicalSrc in ancestors {
        raise new(globalThis.Error, f"Cannot fork schema with a linked directory cycle: {src}");
    }
    ancestors.add(canonicalSrc);
    if dest is not None {
        mkdirSync(dest, rec(recursive=True));
    }
    try {
        for dirent in readdirSync(src, rec(withFileTypes=True)) {
            entryPath = join(src, dirent.name);
            destPath = None if dest is None else join(dest, dirent.name);
            canonicalEntry = resolveSchemaCopyPath(allowedRoot, entryPath);
            stats = statSync(canonicalEntry);
            if stats.isDirectory() {
                walkSchemaTree(canonicalEntry, destPath, allowedRoot, ancestors);
            } elif not stats.isFile() {
                raise new(
                    globalThis.Error,
                    f"Cannot fork schema with linked or unsupported entry: {entryPath}",
                );
            } elif destPath is not None {
                copyFileSync(canonicalEntry, destPath);
            }
        }
    } finally {
        ancestors.remove(canonicalSrc);
    }
}

def:priv fingerprintDir(folder: str) -> str {
    hash = createHash("sha256");
    def walk(current: str, rel: str) {
        for dirent in sorted(
            readdirSync(current, rec(withFileTypes=True)), key=lambda (e: any) -> str { e.name }
        ) {
            abs = join(current, dirent.name);
            relPath = f"{rel}/{dirent.name}" if rel else dirent.name;
            if dirent.isDirectory() {
                hash.update(f"D:{relPath}\n");
                walk(abs, relPath);
            } elif dirent.isFile() {
                contents = readFileSync(abs);
                hash.update(f"F:{relPath}:{contents.length}:");
                hash.update(contents);
                hash.update("\n");
            } else {
                target = "";
                try {
                    target = readlinkSync(abs);
                } except Exception {}
                hash.update(f"O:{relPath}:{target}\n");
            }
        }
    }
    walk(folder, "");
    return hash.digest("hex");
}

def:priv fingerprintIfExists(folder: str) -> any {
    return fingerprintDir(folder) if existsSync(folder) else None;
}

async def:priv prepareDefaultConfigUpdate(projectRoot: str, schemaName: str) -> any {
    configPath = resolveConfigFilePath(projectRoot);
    if missing(configPath) {
        configPath = join(projectRoot, "openspec", "config.yaml");
    }
    FileSystemUtils.assertProjectArtifactPath(projectRoot, configPath);
    file = basename(configPath);
    def refuse(reason: str) -> any {
        return new(globalThis.Error, f"Cannot set the default schema: {reason}");
    }
    yaml = need("yaml");
    if not existsSync(configPath) {
        if not await FileSystemUtils.canWriteFile(configPath) {
            raise refuse(f"{dirname(configPath)} is not writable");
        }
        return rec(
            path=configPath,
            content=globalThis.Buffer.from(yaml.stringify(rec(schema=schemaName))),
            originalContent=None,
            originalMode=None,
        );
    }
    stats = lstatSync(configPath);
    if stats.isSymbolicLink() {
        raise refuse(f"{file} must be a regular file, not a symbolic link");
    }
    if not stats.isFile() {
        raise refuse(f"{file} must be a regular file");
    }
    if not await FileSystemUtils.canWriteFile(configPath)
        or not await FileSystemUtils.canWriteFile(dirname(configPath))
    {
        raise refuse(f"{file} is not writable");
    }
    originalContent = readFileSync(configPath);
    config = yaml.parseDocument(originalContent.toString("utf-8"));
    if len(config.errors) > 0 {
        raise refuse(f"{file} is invalid YAML");
    }
    if not same(config.contents, JsNull) and not yaml.isMap(config.contents) {
        raise refuse(f"{file} must contain a YAML object");
    }
    config.set("schema", schemaName);
    globalThis.Reflect.apply(config["delete"], config, ["defaultSchema"]);
    return rec(
        path=configPath,
        content=globalThis.Buffer.from(config.toString()),
        originalContent=originalContent,
        originalMode=stats.mode,
    );
}

def:priv configMatchesPreparedState(prepared: any) -> bool {
    if prepared.originalContent is None {
        return not existsSync(prepared.path);
    }
    if not existsSync(prepared.path) {
        return False;
    }
    stats = lstatSync(prepared.path);
    return stats.isFile()
        and not stats.isSymbolicLink()
        and stats.mode == prepared.originalMode
        and readFileSync(prepared.path).equals(prepared.originalContent);
}

async def schemaWhichCommand(name: any = None, options: any = None) {
    json = at(options, "json");
    try {
        projectRoot = process.cwd();
        if at(options, "all") {
            schemas = [
                r
                for r in [getSchemaResolution(n, projectRoot) for n in listSchemas(projectRoot)]
                if r is not None
            ];
            if json {
                emit(schemas);
                return;
            }
            if not schemas {
                globalThis.console.log("No schemas found.");
                return;
            }
            for (source, label) in [
                ("project", "Project"),
                ("user", "User"),
                ("package", "Package"),
            ] {
                group = [s for s in schemas if s.source == source];
                if group {
                    globalThis.console.log(f"\n{label} schemas:");
                    for s in group {
                        shadowInfo = f" (shadows: {', '.join([x.source for x in s.shadows])})"
                            if s.shadows
                            else "";
                        globalThis.console.log(f"  {s.name}{shadowInfo}");
                    }
                }
            }
            return;
        }
        if not name {
            globalThis.console.error(
                "Error: Schema name is required (or use --all to list all schemas)"
            );
            process.exitCode = 1;
            return;
        }
        resolution = getSchemaResolution(name, projectRoot);
        if resolution is None {
            notFound(json, name, projectRoot, None);
        } elif json {
            emit(resolution);
        } else {
            globalThis.console.log(f"Schema: {resolution.name}");
            globalThis.console.log(f"Source: {resolution.source}");
            globalThis.console.log(f"Path: {resolution.path}");
            if resolution.shadows {
                globalThis.console.log("\nShadows:");
                for shadow in resolution.shadows {
                    globalThis.console.log(f"  {shadow.source}: {shadow.path}");
                }
            }
        }
    } except Exception as e {
        failWith(False, e, "valid");
    }
}

async def schemaValidateCommand(name: any = None, options: any = None) {
    json = at(options, "json");
    verbose = truthy(at(options, "verbose")) and not json;
    try {
        projectRoot = process.cwd();
        if name {
            schemaDir = getSchemaDir(name, projectRoot);
            if missing(schemaDir) {
                notFound(json, name, projectRoot, "valid");
                return;
            }
            if verbose {
                globalThis.console.log(f"Validating {name}...");
            }
            result = validateSchema(schemaDir, verbose);
            if json {
                emit(rec(name=name, path=schemaDir, valid=result.valid, issues=result.issues));
            } else {
                globalThis.console.log(
                    f"✓ Schema '{name}' is valid"
                        if result.valid
                        else f"✗ Schema '{name}' has errors:",
                );
                for issue in result.issues {
                    globalThis.console.log(f"  {issue.level}: {issue.message}");
                }
            }
            if not result.valid {
                process.exitCode = 1;
            }
            return;
        }
        schemasDir = getProjectSchemasDir(projectRoot);
        if not existsSync(schemasDir) {
            if json {
                emit(rec(valid=True, message="No project schemas directory found", schemas=[]));
            } else {
                globalThis.console.log("No project schemas directory found.");
            }
            return;
        }
        results: list[any] = [];
        for dirent in readdirSync(schemasDir, rec(withFileTypes=True)) {
            schemaDir = join(schemasDir, dirent.name);
            if not isSchemaDir(schemasDir, dirent)
                or not existsSync(join(schemaDir, "schema.yaml"))
            {
                continue;
            }
            if verbose {
                globalThis.console.log(f"\nValidating {dirent.name}...");
            }
            result = validateSchema(schemaDir, verbose);
            results.append(
                rec(name=dirent.name, path=schemaDir, valid=result.valid, issues=result.issues)
            );
        }
        anyInvalid = any([not r.valid for r in results]);
        if json {
            emit(rec(valid=not anyInvalid, schemas=results));
        } elif not results {
            globalThis.console.log("No schemas found in project.");
            return;
        } else {
            globalThis.console.log("\nValidation Results:");
            for r in results {
                globalThis.console.log(f"  {'✓' if r.valid else '✗'} {r.name}");
                for issue in r.issues {
                    globalThis.console.log(f"    {issue.level}: {issue.message}");
                }
            }
        }
        if anyInvalid {
            process.exitCode = 1;
        }
    } except Exception as e {
        failWith(json, e, "valid");
    }
}

async def:priv makeSpinner(options: any) -> any {
    return None if at(options, "json") else (await load("ora")).default();
}

def:priv rejectName(json: any, name: str, key: str) -> bool {
    if isValidSchemaName(name) {
        return False;
    }
    fail(
        json,
        globalThis.Object.fromEntries([
            [key, False],
            ["error", f"Invalid schema name '{name}'. Use kebab-case (e.g., my-workflow)"],
        ]),
        [f"Error: Invalid schema name '{name}'", KEBAB_HINT],
    );
    return True;
}

def:priv installFork(
    source: str,
    destinationName: str,
    sourceDir: str,
    schemasDir: str,
    destinationDir: str,
    authorized: any,
    spinner: any,
) {
    mkdirSync(schemasDir, rec(recursive=True));
    stagingDir = mkdtempSync(join(schemasDir, ".fork-staging-"));
    try {
        walkSchemaTree(sourceDir, stagingDir, sourceDir, set());
        stagedSchemaPath = join(stagingDir, "schema.yaml");
        doc = need("yaml").parseDocument(readFileSync(stagedSchemaPath, "utf-8"));
        doc.set("name", destinationName);
        writeFileSync(stagedSchemaPath, doc.toString());
        try {
            parseSchema(readFileSync(stagedSchemaPath, "utf-8"));
        } except Exception as e {
            raise new(
                globalThis.Error,
                f"The staged fork of '{source}' is not a valid schema (the source may have changed during copy); "
                    + f"aborted, '{destinationName}' was not modified.",
                rec(cause=js_error(e)),
            );
        }
        if authorized is None {
            renameSync(stagingDir, destinationDir);
            return;
        }
        if spinner is not None {
            spinner.text = f"Replacing existing schema '{destinationName}'...";
        }
        if fingerprintIfExists(destinationDir) != authorized {
            raise new(
                globalThis.Error,
                f"Schema '{destinationName}' at {destinationDir} changed on disk while the fork was being prepared. "
                    + "Aborted to preserve those concurrent changes; nothing was overwritten. Re-run the fork to overwrite the current contents.",
            );
        }
        backupDir = f"{destinationDir}.fork-backup-{process.pid}-{globalThis.Date.now()}";
        renameSync(destinationDir, backupDir);
        try {
            renameSync(stagingDir, destinationDir);
        } except Exception as e {
            installError = js_error(e);
            try {
                renameSync(backupDir, destinationDir);
            } except Exception as r {
                raise new(
                    globalThis.Error,
                    f"Failed to install the forked schema and could not restore the previous '{destinationName}'. "
                        + f"Your previous schema is preserved at {backupDir}; move it back to {destinationDir} to restore. "
                        + f"Restore error: {js_error(r).message}",
                    rec(cause=installError),
                );
            }
            raise installError;
        }
        if fingerprintDir(backupDir) == authorized {
            rmSync(backupDir, rec(recursive=True, force=True));
        } else {
            globalThis.console.error(
                f"Warning: the previous '{destinationName}' changed during the fork and was NOT deleted; "
                    + f"its pre-fork copy is preserved at {backupDir}.",
            );
        }
    } except Exception as e {
        try {
            rmSync(stagingDir, rec(recursive=True, force=True));
        } except Exception {}
        raise js_error(e);
    }
}

async def schemaForkCommand(source: str, name: any = None, options: any = None) {
    json = at(options, "json");
    spinner = await makeSpinner(options);
    try {
        projectRoot = process.cwd();
        destinationName = name or f"{source}-custom";
        if rejectName(json, destinationName, "forked") {
            return;
        }
        sourceDir = getSchemaDir(source, projectRoot);
        if missing(sourceDir) {
            notFound(json, source, projectRoot, "forked");
            return;
        }
        resolution = getSchemaResolution(source, projectRoot);
        sourceLocation = "package" if resolution is None else resolution.source;
        trustedSourceDir = realpathSync(sourceDir);
        walkSchemaTree(trustedSourceDir, None, trustedSourceDir, set());
        parseSchema(readFileSync(join(trustedSourceDir, "schema.yaml"), "utf-8"));
        schemasDir = getProjectSchemasDir(projectRoot);
        destinationDir = join(schemasDir, destinationName);
        resolvedDestination = realpathSync(destinationDir)
            if existsSync(destinationDir)
            else resolve(destinationDir);
        if resolvedDestination == trustedSourceDir {
            raise new(
                globalThis.Error,
                f"Cannot fork schema '{source}' onto itself; choose a different destination name",
            );
        }
        destinationExists = existsSync(destinationDir);
        if destinationExists and not at(options, "force") {
            fail(
                json,
                rec(
                    forked=False,
                    error=f"Schema '{destinationName}' already exists",
                    suggestion="Use --force to overwrite",
                ),
                [
                    f"Error: Schema '{destinationName}' already exists at {destinationDir}",
                    "Use --force to overwrite",
                ],
            );
            return;
        }
        authorized = fingerprintDir(destinationDir) if destinationExists else None;
        if spinner is not None {
            spinner.start(f"Forking '{source}' to '{destinationName}'...");
        }
        installFork(
            source,
            destinationName,
            trustedSourceDir,
            schemasDir,
            destinationDir,
            authorized,
            spinner,
        );
        if spinner is not None {
            spinner.succeed(f"Forked '{source}' to '{destinationName}'");
        }
        if json {
            emit(
                rec(
                    forked=True,
                    source=source,
                    sourcePath=sourceDir,
                    sourceLocation=sourceLocation,
                    destination=destinationName,
                    destinationPath=destinationDir,
                ),
            );
        } else {
            globalThis.console.log(f"\nSource: {sourceDir} ({sourceLocation})");
            globalThis.console.log(f"Destination: {destinationDir}");
            globalThis.console.log("\nYou can now customize the schema at:");
            globalThis.console.log(f"  {destinationDir}/schema.yaml");
        }
    } except Exception as e {
        if spinner is not None {
            spinner.fail("Fork failed");
        }
        failWith(json, e, "forked");
    }
}

def:priv buildArtifacts(ids: list[any]) -> list[any] {
    artifacts: list[any] = [];
    for id in ids {
        (_, description, generates, template) = [a for a in DEFAULT_ARTIFACTS if a[0] == id][0];
        requires: list[str] = [];
        if id == "specs" and "proposal" in ids {
            requires = ["proposal"];
        } elif id == "design" and "specs" in ids {
            requires = ["specs"];
        } elif id == "tasks" and "design" in ids {
            requires = ["design"];
        } elif id == "tasks" and "specs" in ids {
            requires = ["specs"];
        }
        artifacts.append(
            rec(
                id=id,
                generates=generates,
                description=description,
                template=template,
                requires=requires,
            ),
        );
    }
    return artifacts;
}

def:priv installSchema(
    projectRoot: str,
    name: str,
    schemaDir: str,
    schema: any,
    prepared: any,
    authorized: any,
    schemaExists: bool,
) {
    schemasDir = getProjectSchemasDir(projectRoot);
    mkdirSync(schemasDir, rec(recursive=True));
    stagingDir = mkdtempSync(join(schemasDir, ".init-staging-"));
    configStagingDir: any = None;
    stagedConfigPath: any = None;
    ops = schemaInitFileOperations;
    try {
        writeFileSync(join(stagingDir, "schema.yaml"), need("yaml").stringify(schema));
        for artifact in schema.artifacts {
            templatePath = join(stagingDir, "templates", artifact.template);
            mkdirSync(dirname(templatePath), rec(recursive=True));
            writeFileSync(
                templatePath,
                TEMPLATES.get(artifact.id, f"# {artifact.id}\n\n<!-- Add content here -->\n"),
            );
        }
        validation = validateSchema(stagingDir);
        if not validation.valid {
            raise new(
                globalThis.Error,
                "Generated schema failed validation: "
                    + "; ".join([i.message for i in validation.issues]),
            );
        }
        if prepared is not None {
            configStagingDir = mkdtempSync(join(dirname(prepared.path), ".schema-init-config-"));
            stagedConfigPath = join(configStagingDir, basename(prepared.path));
            writeFileSync(stagedConfigPath, prepared.content);
            if prepared.originalMode is not None {
                chmodSync(stagedConfigPath, prepared.originalMode);
            }
        }
        FileSystemUtils.assertProjectArtifactPath(projectRoot, schemaDir);
        if prepared is not None {
            FileSystemUtils.assertProjectArtifactPath(projectRoot, prepared.path);
        }
        if fingerprintIfExists(schemaDir) != authorized {
            raise new(
                globalThis.Error,
                f"Schema '{name}' changed on disk while initialization was being prepared. "
                    + "Aborted to preserve those concurrent changes.",
            );
        }
        if prepared is not None and not configMatchesPreparedState(prepared) {
            raise new(
                globalThis.Error,
                f"{basename(prepared.path)} changed on disk while initialization was being prepared. "
                    + "Aborted to preserve those concurrent changes.",
            );
        }
        token = f"{process.pid}-{globalThis.Date.now()}";
        schemaBackup = f"{schemaDir}.init-backup-{token}";
        configBackup = None if prepared is None else f"{prepared.path}.init-backup-{token}";
        schemaBackedUp = False;
        configBackedUp = False;
        schemaInstalled = False;
        configInstalled = False;
        try {
            if schemaExists {
                ops.renameSync(schemaDir, schemaBackup);
                schemaBackedUp = True;
            }
            if prepared is not None and prepared.originalContent is not None {
                ops.renameSync(prepared.path, configBackup);
                configBackedUp = True;
            }
            ops.renameSync(stagingDir, schemaDir);
            schemaInstalled = True;
            if prepared is not None {
                ops.renameSync(stagedConfigPath, prepared.path);
                configInstalled = True;
            }
        } except Exception as e {
            installError = js_error(e);
            rollbackErrors: list[str] = [];
            try {
                if configInstalled {
                    rmSync(prepared.path, rec(force=True));
                }
                if configBackedUp {
                    ops.renameSync(configBackup, prepared.path);
                }
            } except Exception as r {
                rollbackErrors.append(f"config: {js_error(r).message}");
            }
            try {
                if schemaInstalled {
                    rmSync(schemaDir, rec(recursive=True, force=True));
                }
                if schemaBackedUp {
                    ops.renameSync(schemaBackup, schemaDir);
                }
            } except Exception as r {
                rollbackErrors.append(f"schema: {js_error(r).message}");
            }
            if rollbackErrors {
                configName = "the config file" if prepared is None else prepared.path;
                raise new(
                    globalThis.Error,
                    f"Schema initialization failed and rollback was incomplete ({', '.join(rollbackErrors)}). "
                        + f"Recovery backups may remain beside {schemaDir} and {configName}.",
                    rec(cause=installError),
                );
            }
            raise installError;
        }
        for (done, backup) in [(schemaBackedUp, schemaBackup), (configBackedUp, configBackup)] {
            if not done {
                continue;
            }
            try {
                rmSync(backup, rec(recursive=True, force=True));
            } except Exception as c {
                globalThis.console.error(
                    f"Warning: initialization succeeded, but the backup at {backup} could not be removed: {js_error(c).message}",
                );
            }
        }
    } except Exception as e {
        try {
            rmSync(stagingDir, rec(recursive=True, force=True));
        } except Exception {}
        raise js_error(e);
    } finally {
        if configStagingDir is not None {
            try {
                rmSync(configStagingDir, rec(recursive=True, force=True));
            } except Exception {}
        }
    }
}

async def schemaInitCommand(name: str, options: any = None) {
    json = at(options, "json");
    spinner = await makeSpinner(options);
    try {
        projectRoot = process.cwd();
        if rejectName(json, name, "created") {
            return;
        }
        schemaDir = join(getProjectSchemasDir(projectRoot), name);
        schemaExists = existsSync(schemaDir);
        if schemaExists and not at(options, "force") {
            fail(
                json,
                rec(
                    created=False,
                    error=f"Schema '{name}' already exists",
                    suggestion=INIT_EXISTS_HINT,
                ),
                [f"Error: Schema '{name}' already exists at {schemaDir}", INIT_EXISTS_HINT],
            );
            return;
        }
        setDefault = at(options, "default");
        description: any = None;
        ids: any = None;
        explicit = at(options, "description") is not None or at(options, "artifacts") is not None;
        if not json and not explicit and truthy(process.stdout.isTTY) {
            prompts = merge(await load("@inquirer/prompts"));
            description = await prompts.input(
                rec(message="Schema description:", default=f"Custom workflow schema for {name}")
            );
            ids = await prompts.checkbox(
                rec(
                    message="Select artifacts to include:",
                    theme=rec(icon=rec(checked="[x]", unchecked="[ ]")),
                    choices=[rec(name=a, value=a, checked=True) for a in ARTIFACT_IDS],
                ),
            );
            if len(ids) == 0 {
                globalThis.console.error("Error: At least one artifact must be selected");
                process.exitCode = 1;
                return;
            }
            if setDefault is None
                and await prompts.confirm(
                    rec(message="Set as project default schema?", default=False)
                )
            {
                setDefault = True;
            }
        } else {
            description = at(options, "description") or f"Custom workflow schema for {name}";
            requested: any = at(options, "artifacts");
            ids = [a.trim() for a in requested.split(",")] if requested else list(ARTIFACT_IDS);
            for id in ids {
                if id not in ARTIFACT_IDS {
                    fail(
                        json,
                        rec(created=False, error=f"Unknown artifact '{id}'", valid=ARTIFACT_IDS),
                        [
                            f"Error: Unknown artifact '{id}'",
                            f"Valid artifacts: {', '.join(ARTIFACT_IDS)}",
                        ],
                    );
                    return;
                }
            }
        }
        schema = rec(name=name, version=1, description=description, artifacts=buildArtifacts(ids));
        if "tasks" in ids {
            schema.apply = rec(requires=["tasks"], tracks="tasks.md");
        }
        prepared = await prepareDefaultConfigUpdate(projectRoot, name) if setDefault else None;
        FileSystemUtils.assertProjectArtifactPath(projectRoot, schemaDir);
        authorized = fingerprintDir(schemaDir) if schemaExists else None;
        if spinner is not None {
            spinner.start(f"Creating schema '{name}'...");
        }
        installSchema(projectRoot, name, schemaDir, schema, prepared, authorized, schemaExists);
        if spinner is not None {
            spinner.succeed(f"Created schema '{name}'");
        }
        if json {
            emit(
                rec(
                    created=True,
                    path=schemaDir,
                    schema=name,
                    artifacts=ids,
                    setAsDefault=setDefault or False,
                ),
            );
        } else {
            globalThis.console.log(f"\nSchema created at: {schemaDir}");
            globalThis.console.log(f"\nArtifacts: {', '.join(ids)}");
            if setDefault {
                globalThis.console.log("\nSet as project default schema.");
            }
            globalThis.console.log("\nNext steps:");
            globalThis.console.log(f"  1. Edit {schemaDir}/schema.yaml to customize artifacts");
            globalThis.console.log("  2. Modify templates in the schema directory");
            globalThis.console.log(f"  3. Use with: openspec new --schema {name}");
        }
    } except Exception as e {
        if spinner is not None {
            spinner.fail("Creation failed");
        }
        failWith(json, e, "created");
    }
}
