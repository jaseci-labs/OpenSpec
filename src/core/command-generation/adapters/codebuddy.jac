glob codebuddyAdapter: any = commandAdapter(
    "codebuddy",
    ".codebuddy/commands/opsx/*.md",
    frontmatter(["name", "description", "argument-hint: \"[command arguments]\""]),
);
