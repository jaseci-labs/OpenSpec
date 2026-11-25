import from "node:process" { default as process }

def:priv flagged(env: any, key: str, neutral: list[str]) -> bool {
    value: any = (env ?? process.env)[key];
    return value is not None and value.trim().toLowerCase() not in neutral;
}

def isDoNotTrackSet(env: any = None) -> bool {
    return flagged(env, "DO_NOT_TRACK", ["", "0", "false", "no", "off"]);
}

def isTelemetryDisabledByEnv(env: any = None) -> bool {
    return flagged(env, "OPENSPEC_TELEMETRY", ["1", "true", "yes", "on"]);
}

def isTelemetryOptedOutByEnv(env: any = None) -> bool {
    return isTelemetryDisabledByEnv(env) or isDoNotTrackSet(env);
}
