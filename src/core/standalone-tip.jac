glob STANDALONE_TIP_MESSAGE: str = "Tip: OpenSpec also comes as a standalone app that runs without Node.js. To switch, run 'openspec install'.";

async def maybeShowStandaloneTip(options: any = None) {
    if isCiEnvironment() or getStandaloneBinaryPath() {
        return;
    }
    try {
        raw = readRawConfig();
        if same(raw, JsNull) or same(raw["standaloneTipSeen"], True) or at(options, "silent") {
            return;
        }
        if getCliInstallInfo().scope != "global" {
            return;
        }
        await markConfigFlag("standaloneTipSeen");
        globalThis.console.error(f"\n{STANDALONE_TIP_MESSAGE}");
    } except Exception {}
}
