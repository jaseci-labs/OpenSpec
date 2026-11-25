glob crushAdapter: any = commandAdapter(
    "crush", ".crush/commands/opsx/*.md", frontmatter(["name", "description", "category", "tags"])
);
