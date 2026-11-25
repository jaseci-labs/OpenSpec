glob qoderAdapter: any = commandAdapter(
    "qoder", ".qoder/commands/opsx/*.md", frontmatter(["name", "description", "category", "tags"])
);
