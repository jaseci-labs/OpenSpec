glob DESCRIPTION_BUDGET: int = 17;

glob:priv ONBOARDING_COMMANDS: list[any] = [
    rec(workflow=w, command=f"/opsx:{w}", skill=s, description=d)
    for (w, s, d) in [
        ("propose", "openspec-propose", "Start a change"),
        ("new", "openspec-new-change", "Scaffold a change"),
        ("continue", "openspec-continue-change", "Next artifact"),
        ("apply", "openspec-apply-change", "Implement tasks"),
    ]
];

def getOnboardingCommands(workflows: list[str]) -> list[any] {
    return [c for c in ONBOARDING_COMMANDS if c.workflow in workflows];
}

def formatOptionalWorkflowsNote(installedWorkflows: list[str]) -> any {
    absent = [w for w in ALL_WORKFLOWS if w not in installedWorkflows];
    if not absent {
        return JsNull;
    }
    (label, pronoun) = ("workflow is", "it") if len(absent) == 1 else ("workflows are", "them");
    return [
        f"Note: {len(absent)} more {label} available ({', '.join(absent)}).",
        f"Add {pronoun} with `openspec config profile`.",
    ];
}
