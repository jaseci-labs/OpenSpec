glob qwenAdapter: any = commandAdapter(
    "qwen", ".qwen/commands/opsx-*.md", frontmatter(["description"])
);
