def:priv withArguments(body: str) -> str {
    if found(body, "\\$(?:ARGUMENTS\\b|[1-9]\\d*\\b)")
        or found(body, "^\\*\\*Input\\*\\*:\\s*None required\\b", "im")
    {
        return body;
    }
    block = "^\\*\\*Input\\*\\*:[^\\r\\n]*(?:\\r?\\n(?!\\r?\\n)[^\\r\\n]*)*";
    return provideArguments(body, "$ARGUMENTS", block, "\r\n" if "\r\n" in body else "\n");
}

glob opencodeAdapter: any = commandAdapter(
    "opencode", ".opencode/commands/opsx-*.md", frontmatter(["description"], withArguments)
);
