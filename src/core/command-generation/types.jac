import from "path" { default as path }

type CommandContent = any;
type ToolCommandAdapter = any;
type GeneratedCommand = any;

def commandAdapter(
    toolId: str, pattern: str, formatFile: any, invocationPrefix: any = None
) -> any {
    return merge(
        rec(
            toolId=toolId,
            getFilePath=lambda (commandId: str) -> str {
                path.join(*[p.replace("*", commandId) for p in pattern.split("/")])
            },
        ),
        rec(invocationPrefix=invocationPrefix) if invocationPrefix else None,
        rec(formatFile=formatFile),
    );
}

def provideArguments(
    body: str, placeholder: str, pattern: str = "^\\*\\*Input\\*\\*:[^\\n]*$", eol: str = "\n"
) -> str {
    return sub(
        body,
        pattern,
        lambda (input: str) -> str { f"{input}{eol}**Provided arguments**: {placeholder}" },
        "m",
    );
}

def headedFile(content: any) -> str {
    return f"# {content.name}\n\n{content.description}\n\n{content.body}\n";
}
