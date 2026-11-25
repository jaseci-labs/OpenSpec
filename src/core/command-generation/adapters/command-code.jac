def:priv withArguments(body: str) -> str {
    provided = "^\\*\\*Provided arguments\\*\\*:\\s*(?:\\$(?:ARGUMENTS|@)|\\$\\{(?:ARGUMENTS|@)\\})\\s*$";
    return body if found(body, provided, "m") else provideArguments(body, "$ARGUMENTS");
}

glob commandCodeAdapter: any = commandAdapter(
    "command-code",
    ".commandcode/commands/opsx-*.md",
    lambda (c: any) -> str { withArguments(c.body) + "\n" },
);
