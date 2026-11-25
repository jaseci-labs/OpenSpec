glob:priv adapters: any = new(globalThis.Map);

glob CommandAdapterRegistry: any = rec(
    register=lambda (adapter: any) { adapters.set(adapter.toolId, adapter); },
    get=lambda (toolId: str) -> any { adapters.get(toolId) },
    getAll=lambda -> any { globalThis.Array.from(adapters.values()) },
    has=lambda (toolId: str) -> bool { adapters.has(toolId) },
);

with entry {
    for a in [
        amazonQAdapter,
        antigravityAdapter,
        atomcodeAdapter,
        auggieAdapter,
        bobAdapter,
        claudeAdapter,
        clineAdapter,
        commandCodeAdapter,
        devinAdapter,
        codebuddyAdapter,
        codeStudioAdapter,
        continueAdapter,
        costrictAdapter,
        crushAdapter,
        cursorAdapter,
        easycodeAdapter,
        factoryAdapter,
        geminiAdapter,
        githubCopilotAdapter,
        gigacodeAdapter,
        iflowAdapter,
        junieAdapter,
        kilocodeAdapter,
        kiroAdapter,
        ohMyPiAdapter,
        opencodeAdapter,
        piAdapter,
        codeassistantAdapter,
        qoderAdapter,
        lingmaAdapter,
        qwenAdapter,
        roocodeAdapter,
        traeAdapter,
        zcodeAdapter,
    ] {
        CommandAdapterRegistry.register(a);
    }
}
