glob codeassistantAdapter: any = commandAdapter(
    "codeassistant", ".codeassistant/commands/opsx-*.md", frontmatter(["description"])
);
