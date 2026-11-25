import from "node:fs" { promises as fs }
import from "node:path" { default as path }
import from "node:os" { default as os }

type TelemetryConfig = any;

type GlobalConfig = any;

glob CONFIG_DIR_NAME: str = GLOBAL_CONFIG_DIR_NAME,
     CONFIG_FILE_NAME: str = GLOBAL_CONFIG_FILE_NAME;

glob:priv TELEMETRY_FIELDS: list[str] = ["anonymousId", "noticeSeen"];

async def:priv readConfigFile(configPath: str) -> tuple[str, any] {
    try {
        parsed = globalThis.JSON.parse(await fs.readFile(configPath, "utf-8"));
        return ("ok", parsed) if isConfigRootObject(parsed) else ("invalid", rec());
    } except Exception as e {
        return ("missing" if at(js_error(e), "code") == "ENOENT" else "invalid", rec());
    }
}

async def:priv writeConfigFile(configPath: str, config: any) {
    await fs.mkdir(path.dirname(configPath), rec(recursive=True));
    await fs.writeFile(configPath, globalThis.JSON.stringify(config, None, 2) + "\n");
}

async def:priv migrateLegacyTelemetryConfig(configPath: str, config: any, persist: bool) -> any {
    legacyPath = path.join(os.homedir(), ".config", CONFIG_DIR_NAME, CONFIG_FILE_NAME);
    current: any = config["telemetry"];
    if path.resolve(configPath) == path.resolve(legacyPath)
        or truthy(current) and all(current[field] is not None for field in TELEMETRY_FIELDS)
    {
        return config;
    }
    legacy: any = (await readConfigFile(legacyPath))[1]["telemetry"];
    current = rec() if missing(current) else current;
    if not truthy(legacy)
        or not any(
            current[field] is None and legacy[field] is not None for field in TELEMETRY_FIELDS
        )
    {
        return config;
    }
    migrated = merge(config, rec(telemetry=merge(legacy, current)));
    if persist {
        try {
            await writeConfigFile(configPath, migrated);
        } except Exception {}
    }
    return migrated;
}

def getConfigPath -> str {
    return path.join(getGlobalConfigDir(), CONFIG_FILE_NAME);
}

async def readConfig -> any {
    configPath = getConfigPath();
    (status, config) = await readConfigFile(configPath);
    return await migrateLegacyTelemetryConfig(configPath, config, status != "invalid");
}

async def writeConfig(updates: any) {
    configPath = getConfigPath();
    if (await readConfigFile(configPath))[0] == "invalid" {
        raise new(globalThis.Error, unreadableGlobalConfigMessage(configPath));
    }
    existing = await readConfig();
    merged = merge(existing, updates);
    if truthy(updates["telemetry"]) and truthy(existing["telemetry"]) {
        merged.telemetry = merge(existing["telemetry"], updates["telemetry"]);
    }
    await writeConfigFile(configPath, merged);
}

async def getTelemetryConfig -> any {
    telemetry = (await readConfig())["telemetry"];
    return rec() if missing(telemetry) else telemetry;
}

async def updateTelemetryConfig(updates: any) {
    await writeConfig(rec(telemetry=merge(await getTelemetryConfig(), updates)));
}
