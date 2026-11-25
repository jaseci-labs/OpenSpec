glob traeAdapter: any = commandAdapter(
    "trae", ".trae/commands/opsx-*.md", frontmatter(["name", "description"])
);
