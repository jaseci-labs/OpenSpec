glob amazonQAdapter: any = commandAdapter(
    "amazon-q", ".amazonq/prompts/opsx-*.md", frontmatter(["description"]), "@"
);
