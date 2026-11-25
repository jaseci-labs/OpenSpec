glob kiroAdapter: any = commandAdapter(
    "kiro", ".kiro/prompts/opsx-*.prompt.md", frontmatter(["description"])
);
