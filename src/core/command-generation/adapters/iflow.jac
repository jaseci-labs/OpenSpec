glob iflowAdapter: any = commandAdapter(
    "iflow",
    ".iflow/commands/opsx-*.md",
    frontmatter([idField("name", "/opsx-"), idField("id", "opsx-"), "category", "description"]),
);
