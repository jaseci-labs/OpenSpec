glob githubCopilotAdapter: any = commandAdapter(
    "github-copilot", ".github/prompts/opsx-*.prompt.md", frontmatter(["description"])
);
