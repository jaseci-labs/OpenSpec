glob costrictAdapter: any = commandAdapter(
    "costrict",
    ".cospec/openspec/commands/opsx-*.md",
    frontmatter(["description", "argument-hint: command arguments"]),
);
