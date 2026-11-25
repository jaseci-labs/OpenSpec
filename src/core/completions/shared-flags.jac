glob COMMON_FLAGS: any = globalThis.Object.fromEntries([
    ["json", rec(name="json", description="Output as JSON")],
    ["jsonValidation", rec(name="json", description="Output validation results as JSON")],
    ["strict", rec(name="strict", description="Enable strict validation mode")],
    ["noInteractive", rec(name="no-interactive", description="Disable interactive prompts")],
    [
        "type",
        rec(
            name="type",
            description="Specify item type when ambiguous",
            takesValue=True,
            values=["change", "spec"],
        ),
    ],
    [
        "store",
        rec(
            name="store",
            description="Store id to use as the OpenSpec root (a store is a standalone OpenSpec repo you've registered)",
            takesValue=True,
        ),
    ],
]);
