import from "node:fs" { existsSync, readFileSync, writeFileSync, mkdirSync }
import from "node:path" { join, win32, posix }
import from "node:os" { platform, homedir }
import from "node:process" { default as process }

type Profile = any;

type Delivery = any;

type TelemetryConfig = any;

type GlobalConfig = any;

type GlobalDataDirOptions = any;

glob GLOBAL_CONFIG_DIR_NAME: str = "openspec",
     GLOBAL_CONFIG_FILE_NAME: str = "config.json",
     GLOBAL_DATA_DIR_NAME: str = "openspec";

glob:priv DEFAULT_CONFIG: any = rec(featureFlags=rec(), profile="core", delivery="skills"),
          warnedInvalidJsonPaths: list[str] = [];

def:priv readJson(filePath: str) -> any {
    return globalThis.JSON.parse(readFileSync(filePath, "utf-8"));
}

def getGlobalConfigDir -> str {
    base: any = process.env["XDG_CONFIG_HOME"];
    if base {
        return join(base, GLOBAL_CONFIG_DIR_NAME);
    }
    if platform() != "win32" {
        return join(homedir(), ".config", GLOBAL_CONFIG_DIR_NAME);
    }
    base = process.env["APPDATA"];
    return join(base, GLOBAL_CONFIG_DIR_NAME)
        if base
        else join(homedir(), "AppData", "Roaming", GLOBAL_CONFIG_DIR_NAME);
}

def getGlobalDataDir(options: any = None) -> str {
    def pick(key: str, fallback: any) -> any {
        value = at(options, key);
        return fallback() if missing(value) else value;
    }
    env = pick("env", lambda -> any { process.env });
    windows = pick("platform", platform) == "win32";
    joined: any = win32.join if windows else posix.join;
    home = lambda -> any { pick("homedir", homedir) };
    if env["XDG_DATA_HOME"] {
        return joined(env["XDG_DATA_HOME"], GLOBAL_DATA_DIR_NAME);
    }
    if not windows {
        return joined(home(), ".local", "share", GLOBAL_DATA_DIR_NAME);
    }
    if env["LOCALAPPDATA"] {
        return joined(env["LOCALAPPDATA"], GLOBAL_DATA_DIR_NAME);
    }
    return joined(home(), "AppData", "Local", GLOBAL_DATA_DIR_NAME);
}

def getGlobalConfigPath -> str {
    return join(getGlobalConfigDir(), GLOBAL_CONFIG_FILE_NAME);
}

def getGlobalConfig -> any {
    configPath = getGlobalConfigPath();
    try {
        parsed = readJson(configPath) if existsSync(configPath) else None;
        if isConfigRootObject(parsed) {
            return merge(
                DEFAULT_CONFIG,
                parsed,
                rec(featureFlags=merge(DEFAULT_CONFIG.featureFlags, parsed["featureFlags"])),
            );
        }
    } except Exception as e {
        if isinstance(js_error(e), globalThis.SyntaxError)
            and configPath not in warnedInvalidJsonPaths
        {
            warnedInvalidJsonPaths.append(configPath);
            globalThis.console.error(f"Warning: Invalid JSON in {configPath}, using defaults");
        }
    }
    return merge(DEFAULT_CONFIG);
}

def isConfigRootObject(parsed: any) -> bool {
    return kind(parsed) == "object"
        and parsed is not JsNull
        and not globalThis.Array.isArray(parsed);
}

def unreadableGlobalConfigMessage(configPath: str) -> str {
    return f'Refusing to overwrite {configPath}: it could not be parsed, so saving would replace every setting in it. Fix it with "openspec config edit", or reset it with "openspec config reset --all".';
}

def isGlobalConfigUnreadable -> bool {
    configPath = getGlobalConfigPath();
    if not existsSync(configPath) {
        return False;
    }
    try {
        return not isConfigRootObject(readJson(configPath));
    } except Exception {
        return True;
    }
}

def saveGlobalConfig(config: any, options: any = None) {
    configDir = getGlobalConfigDir();
    configPath = getGlobalConfigPath();
    if not truthy(at(options, "replaceUnreadable")) and isGlobalConfigUnreadable() {
        raise new(globalThis.Error, unreadableGlobalConfigMessage(configPath));
    }
    if not existsSync(configDir) {
        mkdirSync(configDir, rec(recursive=True));
    }
    writeFileSync(
        configPath, serializeGlobalConfig(withoutUnsetRetiredDelivery(config, configPath)), "utf-8"
    );
}

def:priv withoutUnsetRetiredDelivery(config: any, configPath: str) -> any {
    if config["delivery"] != DEFAULT_CONFIG.delivery {
        return config;
    }
    try {
        if globalThis.Reflect.has(readJson(configPath), "delivery") {
            return config;
        }
    } except Exception {}
    rest = merge(config);
    globalThis.Reflect.deleteProperty(rest, "delivery");
    return rest;
}

def serializeGlobalConfig(config: any) -> str {
    return globalThis.JSON.stringify(config, None, 2) + "\n";
}
