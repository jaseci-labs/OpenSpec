glob:priv z: any = need("zod").z;

glob GlobalConfigSchema: any = z.object(
         rec(
             featureFlags=z.record(z.string(), z.boolean()).optional().default(rec()),
             profile=z.enum(["core", "custom"]).optional().default("core"),
             delivery=z.enum(["both", "skills", "commands"]).optional().default("skills"),
             workflows=z.array(z.string()).optional(),
             defaultStore=z.string().optional().describe(
                 "Store id used as fallback root when no explicit --store, local root, or project-level store: pointer resolves",
             ),
             telemetry=z.object(rec(enabled=z.boolean().optional())).passthrough().optional(),
             completionTipSeen=z.boolean().optional(),
             standaloneTipSeen=z.boolean().optional(),
             skillsScope=z.enum(["global", "project"]).optional(),
         ),
     ).passthrough(),
     DEFAULT_CONFIG: any = rec(featureFlags=rec(), profile="core", delivery="skills");

glob:priv KNOWN_TOP_LEVEL_KEYS: list[str] = [
              "featureFlags",
              "profile",
              "delivery",
              "workflows",
              "defaultStore",
              "telemetry",
              "skillsScope",
          ],
          UNSAFE_KEY_SEGMENTS: list[str] = ["__proto__", "constructor", "prototype"];

def:priv unsafe(keys: list[str]) -> bool {
    return any(key in UNSAFE_KEY_SEGMENTS for key in keys);
}

def:priv isObject(value: any) -> bool {
    return not missing(value) and kind(value) == "object";
}

def hasUnsafeKeySegment(path: str) -> bool {
    return unsafe(path.split("."));
}

def:priv keyPathProblem(keys: list[any]) -> any {
    top = keys[0];
    if any(key.trim() == "" for key in keys) {
        return "Key path must not be empty";
    }
    for key in keys {
        if key in UNSAFE_KEY_SEGMENTS {
            return f'Key segment "{key}" is not allowed';
        }
    }
    if top not in KNOWN_TOP_LEVEL_KEYS {
        return f'Unknown top-level key "{top}"';
    }
    if top == "featureFlags" {
        return "featureFlags values are booleans and do not support nested keys"
            if len(keys) > 2
            else None;
    }
    if top == "telemetry" {
        if len(keys) == 1 {
            return "Set nested keys under telemetry (e.g. telemetry.enabled)";
        }
        rest = ".".join(keys[1:]);
        return None if rest == "enabled" else f'Unknown telemetry key "{rest}" (allowed: enabled)';
    }
    return f'"{top}" does not support nested keys' if len(keys) > 1 else None;
}

def validateConfigKeyPath(path: str) -> any {
    reason = keyPathProblem(path.split("."));
    return rec(valid=True) if reason is None else rec(valid=False, reason=reason);
}

def getNestedValue(target: any, path: str) -> any {
    keys = path.split(".");
    if unsafe(keys) {
        return None;
    }
    for key in keys {
        if not isObject(target) {
            return None;
        }
        target = target[key];
    }
    return target;
}

def setNestedValue(target: any, path: str, value: any) {
    keys = path.split(".");
    if unsafe(keys) {
        return;
    }
    for key in keys[:-1] {
        if not isObject(target[key]) {
            target[key] = rec();
        }
        target = target[key];
    }
    target[keys[-1]] = value;
}

def deleteNestedValue(target: any, path: str) -> bool {
    keys = path.split(".");
    if unsafe(keys) {
        return False;
    }
    for key in keys[:-1] {
        if not isObject(target[key]) {
            return False;
        }
        target = target[key];
    }
    return globalThis.Reflect.has(target, keys[-1])
        and globalThis.Reflect.deleteProperty(target, keys[-1]);
}

def coerceValue(value: any, forceString: bool = False) -> any {
    if forceString {
        return value;
    }
    if value in ["true", "false"] {
        return value == "true";
    }
    trimmed: any = value.trim();
    num = globalThis.Number(value);
    if trimmed != "" and globalThis.Number.isFinite(num) {
        return num;
    }
    if trimmed.startsWith("[") and trimmed.endsWith("]")
        or trimmed.startsWith("{") and trimmed.endsWith("}")
    {
        try {
            parsed = globalThis.JSON.parse(trimmed);
            if isObject(parsed) {
                return parsed;
            }
        } except Exception {}
    }
    return value;
}

def formatValueYaml(value: any, indent: int = 0) -> str {
    pad = "  " * indent;
    if missing(value) {
        return "null";
    }
    if globalThis.Array.isArray(value) {
        return "\n".join([f"{pad}- {formatValueYaml(item, indent + 1)}" for item in value])
            if len(value)
            else "[]";
    }
    if kind(value) != "object" {
        return globalThis.String(value);
    }
    lines = [];
    for (key, val) in globalThis.Object.entries(value) {
        sep = "\n" if isObject(val) and len(globalThis.Object.keys(val)) else " ";
        lines.append(f"{pad}{key}:{sep}{formatValueYaml(val, indent + 1)}");
    }
    return "\n".join(lines) if lines else "{}";
}

def validateConfig(config: any) -> any {
    try {
        GlobalConfigSchema.parse(config);
        return rec(success=True);
    } except Exception as e {
        error = js_error(e);
        if not isinstance(error, z.ZodError) {
            return rec(success=False, error="Unknown validation error");
        }
        return rec(
            success=False,
            error="; ".join([
                f"{'.'.join([globalThis.String(part) for part in issue.path])}: {issue.message}"
                for issue in error.issues
            ]),
        );
    }
}
