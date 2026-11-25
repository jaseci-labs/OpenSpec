glob piAdapter: any = commandAdapter(
    "pi",
    ".pi/prompts/opsx-*.md",
    frontmatter(
        ["description"],
        lambda (body: str) -> str {
            body if "$@" in body or "$ARGUMENTS" in body else provideArguments(body, "$@")
        },
    ),
);
