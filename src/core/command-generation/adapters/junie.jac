glob junieAdapter: any = commandAdapter(
    "junie", ".junie/commands/opsx-*.md", frontmatter(["description"])
);
