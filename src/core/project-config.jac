import from "node:fs" { existsSync, readFileSync, statSync }
import from "node:path" { join }

type DeclarationEntry = any;

type ProjectConfig = any;

glob OPERATION_IDS: list[str] = ["apply", "archive"],
     MAX_CONTEXT_SIZE: int = 50 * 1024,
     ProjectConfigSchema: any = makeProjectConfigSchema();

glob:priv yaml: any = need("yaml");

def:priv makeProjectConfigSchema -> any {
    z = need("zod").z;
    operation = z.object(rec(guidance=z.array(z.string()).optional())).optional();
    return z.object(
        rec(
            schema=z.string().min(1).describe('The workflow schema to use (e.g., "spec-driven")'),
            context=z.string().optional().describe(
                "Project context injected into all artifact instructions"
            ),
            rules=z.record(z.string(), z.array(z.string())).optional().describe(
                "Per-artifact rules, keyed by artifact ID"
            ),
            operations=z.object(rec(apply=operation, archive=operation)).optional().describe(
                "Per-operation advisory guidance"
            ),
            store=z.string().optional().describe(
                "Store id used as the OpenSpec root when no local planning shape exists"
            ),
            githubCopilot=z.object(rec(cloudAgent=z.boolean().optional())).optional().describe(
                "GitHub Copilot integration preferences"
            ),
            skillsScope=z.enum(["project", "global"]).optional().describe(
                "Where this project keeps its OpenSpec skills"
            ),
        ),
    );
}

def:priv warn(message: str) {
    globalThis.console.warn(message);
}

def:priv isRecord(value: any) -> bool {
    return not missing(value) and kind(value) == "object" and not globalThis.Array.isArray(value);
}

def:priv strings(value: any) -> bool {
    return globalThis.Array.isArray(value) and all(kind(item) == "string" for item in value);
}

def:priv firstLine(error: any) -> str {
    error = js_error(error);
    return error.message.split("\n")[0]
        if isinstance(error, globalThis.Error)
        else globalThis.String(error);
}

def loadOperationInputs(projectConfig: any, operationId: str) -> any {
    context: any = at(projectConfig, "context");
    guidance: any = at(projectConfig, "operations", operationId, "guidance");
    return merge(
        None if context is None or not context.trim() else rec(context=context),
        rec(operationGuidance=guidance) if truthy(guidance) and len(guidance) else None,
    );
}

def:priv parseOperations(raw: any) -> any {
    if raw is None {
        return None;
    }
    if not isRecord(raw) {
        warn("Invalid 'operations' field in config (must be object)");
        return None;
    }
    operations = rec();
    for (operationId, value) in globalThis.Object.entries(raw) {
        if operationId not in OPERATION_IDS {
            warn(
                f"Unknown operation ID '{operationId}' in config. Supported operation IDs: {', '.join(OPERATION_IDS)}",
            );
            continue;
        }
        if not isRecord(value) {
            warn(
                f"Invalid 'operations.{operationId}' field in config (must be object), ignoring this operation",
            );
            continue;
        }
        unknownFields = [field for field in globalThis.Object.keys(value) if field != "guidance"];
        if unknownFields {
            warn(
                f"Unknown field(s) in 'operations.{operationId}': {', '.join(unknownFields)}. Supported fields: guidance",
            );
        }
        if value["guidance"] is None {
            continue;
        }
        if not strings(value.guidance) {
            warn(
                f"Guidance for operation '{operationId}' must be an array of strings, ignoring this operation's guidance",
            );
            continue;
        }
        guidance = [item for item in value.guidance if item];
        if len(guidance) < len(value.guidance) {
            warn(f"Some guidance for operation '{operationId}' are empty strings, ignoring them");
        }
        if guidance {
            operations[operationId] = rec(guidance=guidance);
        }
    }
    return operations if len(globalThis.Object.keys(operations)) else None;
}

def:priv parseDeclarationList(raw: any) -> any {
    if raw is None {
        return None;
    }
    if not globalThis.Array.isArray(raw) {
        warn("Invalid 'references' field in config (must be an array of store ids)");
        return None;
    }
    byId: dict[str, any] = {};
    droppedEntries = False;
    droppedRemotes = False;
    for item in raw {
        declaration: any = None;
        if kind(item) == "string" {
            declaration = rec(id=item);
        } elif isRecord(item) and kind(item["id"]) == "string" {
            declaration = rec(id=item.id);
            remote: any = item["remote"];
            if kind(remote) == "string" and len(remote) > 0 {
                declaration.remote = remote;
            } elif remote is not None {
                droppedRemotes = True;
            }
        }
        if declaration is None {
            droppedEntries = True;
        } elif declaration.id not in byId {
            byId[declaration.id] = declaration;
        } elif byId[declaration.id]["remote"] is None and declaration["remote"] is not None {
            byId[declaration.id].remote = declaration.remote;
        }
    }
    if droppedEntries {
        warn("Some 'references' entries are invalid, ignoring them");
    }
    if droppedRemotes {
        warn(
            "Some 'references' remotes are not non-empty strings; the ids are kept without a clone source",
        );
    }
    return list(byId.values()) if byId else None;
}

def:priv describeYamlType(value: any) -> str {
    if value is JsNull {
        return "null";
    }
    if globalThis.Array.isArray(value) {
        return "a nested list";
    }
    return "a mapping" if kind(value) == "object" else f"a {kind(value)}";
}

def:priv describeRulesShapeError(artifactId: str, rules: any) -> str {
    base = f"Rules for '{artifactId}' must be an array of strings, ignoring this artifact's rules";
    if not globalThis.Array.isArray(rules) {
        return f"{base}. rules.{artifactId} is {describeYamlType(rules)}";
    }
    bad = [(index, rule) for (index, rule) in enumerate(rules) if kind(rule) != "string"];
    if not bad {
        return base;
    }
    details = "; ".join([
        f"rules.{artifactId}[{index}] is {describeYamlType(rule)}"
        for (index, rule) in bad
    ]);
    hint = ' — an unquoted ": " makes YAML read the item as a key/value pair; quote the whole scalar to keep it a string.'
        if any(isRecord(rule) for (index, rule) in bad)
        else "";
    return f"{base}. {details}{hint}";
}

def:priv parseRules(raw: any) -> any {
    if not isRecord(raw) {
        warn("Invalid 'rules' field in config (must be object)");
        return None;
    }
    parsedRules = globalThis.Object.create(JsNull);
    hasValidRules = False;
    for (artifactId, rules) in globalThis.Object.entries(raw) {
        if not strings(rules) {
            warn(describeRulesShapeError(artifactId, rules));
            continue;
        }
        validRules = [rule for rule in rules if rule];
        if validRules {
            parsedRules[artifactId] = validRules;
            hasValidRules = True;
        }
        if len(validRules) < len(rules) {
            warn(f"Some rules for '{artifactId}' are empty strings, ignoring them");
        }
    }
    return parsedRules if hasValidRules else None;
}

def:priv parseContext(raw: any) -> any {
    if kind(raw) != "string" {
        warn("Invalid 'context' field in config (must be string)");
        return None;
    }
    size = globalThis.Buffer.byteLength(raw, "utf-8");
    if size > MAX_CONTEXT_SIZE {
        kb: any = size / 1024;
        warn(
            f"Context too large ({kb.toFixed(1)}KB, limit: {globalThis.String(MAX_CONTEXT_SIZE // 1024)}KB)",
        );
        warn("Ignoring context field");
        return None;
    }
    return raw;
}

def:priv parseGithubCopilot(raw: any) -> any {
    if not isRecord(raw) {
        warn("Invalid 'githubCopilot' field in config (must be an object)");
        return None;
    }
    cloudAgent = raw["cloudAgent"];
    if kind(cloudAgent) == "boolean" {
        return rec(cloudAgent=cloudAgent);
    }
    if cloudAgent is not None {
        warn("Invalid 'githubCopilot.cloudAgent' field in config (must be a boolean)");
    }
    return None;
}

def readProjectConfig(projectRoot: str) -> any {
    configPath = resolveConfigFilePath(projectRoot);
    if configPath is JsNull {
        return JsNull;
    }
    try {
        raw = yaml.parse(readFileSync(configPath, "utf-8"));
        if not truthy(raw) or kind(raw) != "object" {
            warn("openspec/config.yaml is not a valid YAML object");
            return JsNull;
        }
        if globalThis.Array.isArray(raw) {
            return JsNull;
        }
        config = rec();
        schema = raw["schema"];
        if kind(schema) == "string" and len(schema) > 0 {
            config.schema = schema;
        } elif schema is not None {
            warn("Invalid 'schema' field in config (must be non-empty string)");
        }
        def parse(key: str, parser: any) {
            if raw[key] is not None {
                value = parser(raw[key]);
                if value is not None {
                    config[key] = value;
                }
            }
        }
        parse("context", parseContext);
        parse("rules", parseRules);
        parse("operations", parseOperations);
        parse("references", parseDeclarationList);
        if raw["store"] is not None {
            if kind(raw.store) == "string" {
                config.store = raw.store;
            } else {
                warn(
                    f"Warning: ignoring invalid store: field in {configPathForWarnings(projectRoot)} (must be a single store id string).",
                );
            }
        }
        parse("githubCopilot", parseGithubCopilot);
        if raw["skillsScope"] is not None {
            if raw.skillsScope in ["project", "global"] {
                config.skillsScope = raw.skillsScope;
            } else {
                warn("Invalid 'skillsScope' field in config (must be \"project\" or \"global\")");
            }
        }
        return config if len(globalThis.Object.keys(config)) else JsNull;
    } except Exception as e {
        warn(
            f"Warning: could not parse {configPathForWarnings(projectRoot)} ({firstLine(e)}); ignoring it.",
        );
        return JsNull;
    }
}

def readConfigParseError(projectRoot: str) -> any {
    filePath = resolveConfigFilePath(projectRoot);
    if filePath is JsNull {
        return JsNull;
    }
    content = "";
    try {
        content = readFileSync(filePath, "utf-8");
    } except Exception as e {
        return rec(kind="read", filePath=filePath, message=firstLine(e));
    }
    try {
        yaml.parse(content);
        return JsNull;
    } except Exception as e {
        return rec(kind="parse", filePath=filePath, message=firstLine(e));
    }
}

def:priv configPathForWarnings(projectRoot: str) -> str {
    configPath = resolveConfigFilePath(projectRoot);
    return join(projectRoot, "openspec", "config.yaml") if configPath is JsNull else configPath;
}

def validateConfigRules(rules: any, validArtifactIds: any) -> list[str] {
    validIds = ", ".join(sorted(globalThis.Array.from(validArtifactIds)));
    return [
        f'Unknown artifact ID in rules: "{artifactId}". It matches no artifact in any available schema. Known artifact IDs: {validIds}'
        for artifactId in globalThis.Object.keys(rules)
        if not validArtifactIds.has(artifactId)
    ];
}

def:priv levenshtein(a: str, b: str) -> int {
    previous = list(range(len(a) + 1));
    for i in range(1, len(b) + 1) {
        current = [i];
        for j in range(1, len(a) + 1) {
            current.append(
                previous[j - 1]
                    if b[i - 1] == a[j - 1]
                    else min(previous[j - 1], current[j - 1], previous[j]) + 1,
            );
        }
        previous = current;
    }
    return previous[len(a)];
}

def suggestSchemas(invalidSchemaName: str, availableSchemas: any) -> str {
    scored = [(levenshtein(invalidSchemaName, s.name), s) for s in availableSchemas];
    suggestions = sorted(
        [pair for pair in scored if pair[0] <= 3], key=lambda (pair: any) -> int { pair[0] }
    )[:3];
    builtIn = [s.name for s in availableSchemas if s.isBuiltIn];
    projectLocal = [s.name for s in availableSchemas if not s.isBuiltIn];
    message = f"Schema '{invalidSchemaName}' not found in openspec/config.yaml\n\n";
    if suggestions {
        message += "Did you mean one of these?\n";
        for (distance, s) in suggestions {
            message += f"  - {s.name} ({'built-in' if s.isBuiltIn else 'project-local'})\n";
        }
        message += "\n";
    }
    message += "Available schemas:\n";
    if builtIn {
        message += f"  Built-in: {', '.join(builtIn)}\n";
    }
    message += f"  Project-local: {', '.join(projectLocal) if projectLocal else '(none found)'}\n";
    return message
        + f"\nFix: Edit openspec/config.yaml and change 'schema: {invalidSchemaName}' to a valid schema name";
}

def readStorePointer(projectRoot: str) -> any {
    configPath = resolveConfigFilePath(projectRoot);
    if configPath is JsNull {
        return rec(filePath=JsNull);
    }
    try {
        raw = yaml.parse(readFileSync(configPath, "utf-8"));
        value = raw["store"] if isRecord(raw) else None;
        if value is None {
            return rec(filePath=configPath);
        }
        if kind(value) == "string" {
            return rec(value=value, filePath=configPath);
        }
        return rec(malformed="non_string", filePath=configPath);
    } except Exception {
        return rec(malformed="unparseable", filePath=configPath);
    }
}

def resolveConfigFilePath(projectRoot: str) -> any {
    for name in ["config.yaml", "config.yml"] {
        candidate = join(projectRoot, "openspec", name);
        if existsSync(candidate) {
            return candidate;
        }
    }
    return JsNull;
}

def storePointerProblem(reason: str) -> str {
    return "the config file could not be read as YAML"
        if reason == "unparseable"
        else "the store key must be a single store id string";
}

def classifyOpenSpecDir(projectRoot: str) -> any {
    openspecDir = join(projectRoot, "openspec");
    return rec(
        hasPlanningShape=any(
            isPlanningDirectorySync(join(openspecDir, name)) for name in ["specs", "changes"]
        ),
        pointer=readStorePointer(projectRoot),
    );
}

def:priv isPlanningDirectorySync(candidatePath: str) -> bool {
    try {
        if not statSync(candidatePath).isDirectory() {
            return False;
        }
    } except Exception {
        return False;
    }
    return not existsSync(getStoreMetadataPath(candidatePath));
}
