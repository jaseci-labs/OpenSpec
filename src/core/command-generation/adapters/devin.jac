glob devinAdapter: any = commandAdapter(
    "devin", ".devin/workflows/opsx-*.md", frontmatter(["name", "description", "category", "tags"])
);
