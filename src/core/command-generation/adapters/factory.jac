glob factoryAdapter: any = commandAdapter(
    "factory",
    ".factory/commands/opsx-*.md",
    frontmatter(["description", "argument-hint: command arguments"]),
);
