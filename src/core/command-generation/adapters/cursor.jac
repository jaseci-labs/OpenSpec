glob cursorAdapter: any = commandAdapter(
    "cursor",
    ".cursor/commands/opsx-*.md",
    frontmatter([idField("name", "/opsx-"), idField("id", "opsx-"), "category", "description"]),
);
