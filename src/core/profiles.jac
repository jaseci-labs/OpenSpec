type WorkflowId = any;

glob CORE_WORKFLOWS: list[str] = ["propose", "explore", "apply", "update", "sync", "archive"],
     ALL_WORKFLOWS: list[str] = [
         "propose",
         "explore",
         "new",
         "continue",
         "apply",
         "update",
         "ff",
         "sync",
         "archive",
         "bulk-archive",
         "verify",
         "onboard",
     ],
     ROUTER_WORKFLOW: str = "router",
     SKILL_WORKFLOWS: list[str] = [*ALL_WORKFLOWS, ROUTER_WORKFLOW];

def withRouter(workflows: list[str]) -> list[str] {
    return workflows
        if not workflows or ROUTER_WORKFLOW in workflows
        else [*workflows, ROUTER_WORKFLOW];
}

def getProfileWorkflows(profile: str, customWorkflows: any = None) -> list[str] {
    if profile != "custom" {
        return CORE_WORKFLOWS;
    }
    workflows: list[str] = [] if missing(customWorkflows) else customWorkflows;
    hits = [i for (i, w) in enumerate(workflows) if w in ["archive", "bulk-archive"]];
    if hits and "sync" not in workflows {
        return [*workflows[:hits[0]], "sync", *workflows[hits[0]:]];
    }
    return workflows;
}
