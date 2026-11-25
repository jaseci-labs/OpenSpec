glob codeStudioAdapter: any = commandAdapter(
    "codestudio", ".codestudio/prompts/opsx-*.prompt.md", frontmatter(["description"])
);
