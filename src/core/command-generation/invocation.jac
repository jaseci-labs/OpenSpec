import from "path" { default as path }

type CommandInvocationStyle = any;
type CommandInvocation = any;

glob CANONICAL_INVOCATION: any = rec(style="namespaced", prefix="/");

def getInvocationStyleForPath(commandFilePath: str) -> str {
    return "flat" if path.basename(commandFilePath).startswith("opsx-") else "namespaced";
}

def getInvocationForAdapter(adapter: any) -> any {
    prefix = adapter["invocationPrefix"];
    return rec(
        style=getInvocationStyleForPath(adapter.getFilePath("explore")),
        prefix=CANONICAL_INVOCATION.prefix if missing(prefix) else prefix,
    );
}

def formatCommandInvocation(invocation: any, commandId: str) -> str {
    return f"{invocation.prefix}opsx{':' if invocation.style == 'namespaced' else '-'}{commandId}";
}

def needsInvocationRewrite(invocation: any) -> bool {
    return invocation.style != CANONICAL_INVOCATION.style
        or invocation.prefix != CANONICAL_INVOCATION.prefix;
}
