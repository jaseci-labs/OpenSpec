import from "node:fs" { existsSync, readFileSync }
import from "node:process" { default as process }

glob COMPLETION_TIP_MESSAGE: str = "Tip: Run 'openspec completion install' for shell completions";

async def:priv decideTip -> str {
    try {
        shell = detectShell()["shell"];
        if not shell {
            return "retire";
        }
        import from .completions.factory { CompletionFactory }
        return "retire" if await CompletionFactory.createInstaller(shell).isInstalled() else "show";
    } except Exception {
        return "show";
    }
}

def readRawConfig -> any {
    configPath = getGlobalConfigPath();
    if not existsSync(configPath) {
        return rec();
    }
    parsed = globalThis.JSON.parse(readFileSync(configPath, "utf-8"));
    return parsed
        if kind(parsed) == "object"
            and not same(parsed, JsNull)
            and not globalThis.Array.isArray(parsed)
        else JsNull;
}

async def markConfigFlag(key: str, value: any = True) {
    current = readRawConfig();
    await writeFileAtomically(
        getGlobalConfigPath(),
        globalThis.JSON.stringify(
            merge(
                current if not missing(current) else rec(),
                globalThis.Object.fromEntries([[key, value]]),
            ),
            None,
            2,
        )
            + "\n",
    );
}

async def maybeShowCompletionTip(options: any = None) {
    if isCiEnvironment() or process.env.OPENSPEC_NO_COMPLETIONS == "1" {
        return;
    }
    try {
        raw = readRawConfig();
        if same(raw, JsNull) or same(raw["completionTipSeen"], True) or at(options, "silent") {
            return;
        }
        decision = await decideTip();
        await markConfigFlag("completionTipSeen");
        if decision == "show" {
            globalThis.console.error(f"\n{COMPLETION_TIP_MESSAGE}");
        }
    } except Exception {}
}
