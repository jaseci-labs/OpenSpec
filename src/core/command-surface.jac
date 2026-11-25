type CommandSurfaceCapability = any;

def resolveCommandInvocation(toolId: str) -> any {
    adapter = CommandAdapterRegistry.get(toolId);
    return getInvocationForAdapter(adapter) if adapter else None;
}

def resolveCommandSurfaceCapability(toolId: str) -> str {
    if CommandAdapterRegistry.has(toolId) {
        return "adapter-backed";
    }
    return "skills-invocable" if toolId in ["codex", "warp"] else "none";
}

def shouldReconcileCommandFilesForTool(toolId: str) -> bool {
    return resolveCommandSurfaceCapability(toolId) == "adapter-backed";
}
