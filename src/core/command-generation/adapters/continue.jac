glob continueAdapter: any = commandAdapter(
    "continue",
    ".continue/prompts/opsx-*.prompt",
    frontmatter(
        [idField("name", "opsx-"), "description", "invokable: true"],
        lambda (body: str) -> str {
            "This workflow prompt is already active. Follow its instructions directly. Do not call a tool named after this workflow.\n\n"
                + body
        },
    ),
);
