glob claudeAdapter: any = commandAdapter(
    "claude",
    ".claude/commands/opsx/*.md",
    frontmatter([
        "name",
        "description",
        f"allowed-tools: {OPENSPEC_CLI_ALLOWED_TOOLS}",
        "category",
        "tags",
    ]),
);
