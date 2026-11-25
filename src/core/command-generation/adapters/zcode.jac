glob zcodeAdapter: any = commandAdapter(
    "zcode", ".zcode/commands/opsx/*.md", frontmatter(["name", "description", "category", "tags"])
);
