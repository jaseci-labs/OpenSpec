glob bobAdapter: any = commandAdapter(
    "bob",
    ".bob/commands/opsx-*.md",
    frontmatter(["description", "argument-hint: command arguments"]),
);
