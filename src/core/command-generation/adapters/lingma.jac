glob lingmaAdapter: any = commandAdapter(
    "lingma", ".lingma/commands/opsx/*.md", frontmatter(["name", "description", "category", "tags"])
);
