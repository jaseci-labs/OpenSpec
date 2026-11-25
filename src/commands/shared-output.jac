import from "node:process" { default as process }

def printJson(payload: any) {
    globalThis.console.log(globalThis.JSON.stringify(payload, None, 2));
}

def asErrorMessage(error: any) -> str {
    return error.message if isinstance(error, globalThis.Error) else globalThis.String(error);
}

def isPromptCancellationError(error: any) -> bool {
    return isinstance(error, globalThis.Error)
        and (
            error.name == "ExitPromptError"
            or "force closed the prompt with SIGINT" in error.message
        );
}

def asStatus(error: any, fallbackCode: str) -> any {
    diagnostic = error["diagnostic"];
    if isinstance(error, StoreError)
        or (truthy(diagnostic) and kind(diagnostic["code"]) == "string")
    {
        return diagnostic;
    }
    return rec(severity="error", code=fallbackCode, message=asErrorMessage(error));
}

def emitFailure(json: any, payload: any, error: any, fallbackCode: str) {
    if not json and isPromptCancellationError(error) {
        globalThis.console.error("Cancelled.");
        process.exitCode = 130;
        return;
    }
    status = asStatus(error, fallbackCode);
    if json {
        prior = payload["status"] if globalThis.Array.isArray(payload["status"]) else [];
        printJson(merge(payload, rec(status=[*prior, status])));
    } else {
        globalThis.console.error(f"Error: {status.message}");
        if status["fix"] {
            globalThis.console.error(f"Fix: {status.fix}");
        }
    }
    process.exitCode = 1;
}
