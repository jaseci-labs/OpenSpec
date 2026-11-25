glob auggieAdapter: any = commandAdapter(
    "auggie",
    ".augment/commands/opsx-*.md",
    frontmatter(["description", "argument-hint: command arguments"]),
);
