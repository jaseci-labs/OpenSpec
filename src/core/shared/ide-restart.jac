type IdeRestartSurface = any;

def resolveIdeRestartSurface(toolIds: list[str], _delivery: any = None) -> any {
    return "skills"
        if [t for t in AI_TOOLS if t["requiresIdeRestart"] and t.value in toolIds]
        else JsNull;
}

def formatIdeRestart(toolIds: list[str], delivery: any = None) -> any {
    surface = resolveIdeRestartSurface(toolIds, delivery);
    return f"Restart your IDE to refresh {surface}." if surface else JsNull;
}
