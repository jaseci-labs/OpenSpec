import from "node:path" { default as path }
import from "node:fs" { existsSync }

glob WORKFLOW_TO_SKILL_DIR: any = globalThis.Object.fromEntries(
    [
        [pair.split("=")[0], f"openspec-{pair.split('=')[1]}"]
        for pair in "explore=explore new=new-change continue=continue-change apply=apply-change update=update-change ff=ff-change sync=sync-specs archive=archive-change bulk-archive=bulk-archive-change verify=verify-change onboard=onboard propose=propose".split()
    ] + [["router", "openspec"]],
);

def:priv toKnownWorkflows(workflows: any) -> list[any] {
    return [w for w in withRouter(workflows) if w in SKILL_WORKFLOWS];
}

def:priv findTool(toolId: str) -> any {
    return AI_TOOLS.find(lambda (t: any) -> bool { t.value == toolId });
}

def:priv skillFile(skillsDir: str, workflow: str) -> str {
    return path.join(skillsDir, WORKFLOW_TO_SKILL_DIR[workflow], "SKILL.md");
}

def getConfiguredToolsForProfileSync(projectPath: str, view: any = None) -> list[str] {
    return getConfiguredTools(projectPath, view ?? DISK_VIEW);
}

def:priv legacyDrift(
    projectPath: str,
    tool: any,
    known: list[any],
    skillsDir: str,
    shared: bool,
    listed: bool,
    view: any,
) -> bool {
    for r in tool["legacySkillsDirs"] or [] {
        for workflow in known {
            legacySkill = skillFile(path.join(projectPath, r, "skills"), workflow);
            if not view.exists(legacySkill) {
                continue;
            }
            currentSkill = skillFile(skillsDir, workflow);
            if not view.exists(currentSkill) or (shared and not listed) {
                return True;
            }
            try {
                if FileSystemUtils.canonicalizeExistingPath(legacySkill)
                    == FileSystemUtils.canonicalizeExistingPath(currentSkill)
                {
                    continue;
                }
                if isRedundantLegacyCopy(view.read(legacySkill), view.read(currentSkill), True) {
                    return True;
                }
            } except Exception {
                return True;
            }
        }
    }
    return False;
}

def hasToolProfileOrDeliveryDrift(
    projectPath: str, toolId: str, desiredWorkflows: any, _delivery: any, view: any = None
) -> bool {
    view = view ?? DISK_VIEW;
    tool = findTool(toolId);
    if not tool or not toolSupportsSkills(tool) {
        return False;
    }
    known = toKnownWorkflows(desiredWorkflows);
    skillsDir = resolveToolSkillsDir(projectPath, tool);
    shared = usesSharedSkills(tool);
    listed = shared and isToolListed(projectPath, toolId, view);
    if legacyDrift(projectPath, tool, known, skillsDir, shared, listed, view) {
        return True;
    }
    if shared
        and (
            not listed
            or ownSkillFolderNeedsWork(
                projectPath,
                tool,
                new(globalThis.Set, [WORKFLOW_TO_SKILL_DIR[w] for w in known]),
                view,
            )
        )
    {
        return True;
    }
    for workflow in SKILL_WORKFLOWS {
        if (workflow in known) != view.exists(skillFile(skillsDir, workflow)) {
            return True;
        }
    }
    return shouldReconcileCommandFilesForTool(toolId)
        and truthy(CommandAdapterRegistry.get(toolId))
        and len(classifyCommandFiles(projectPath, toolId, known, view).generated) > 0;
}

def getToolsNeedingProfileSync(
    projectPath: str,
    desiredWorkflows: any,
    delivery: any,
    configuredTools: any = None,
    view: any = None,
) -> list[any] {
    view = view ?? DISK_VIEW;
    tools = getConfiguredToolsForProfileSync(projectPath, view)
        if missing(configuredTools)
        else globalThis.Array.from(new(globalThis.Set, configuredTools));
    return [
        toolId
        for toolId in tools
        if hasToolProfileOrDeliveryDrift(projectPath, toolId, desiredWorkflows, delivery, view)
    ];
}

def hasProjectConfigDrift(projectPath: str, desiredWorkflows: any, delivery: any) -> bool {
    configuredTools = getConfiguredToolsForProfileSync(projectPath);
    if getToolsNeedingProfileSync(projectPath, desiredWorkflows, delivery, configuredTools) {
        return True;
    }
    known = toKnownWorkflows(desiredWorkflows);
    for toolId in configuredTools {
        tool = findTool(toolId);
        if not tool or not toolSupportsSkills(tool) {
            continue;
        }
        skillsDir = resolveToolSkillsDir(projectPath, tool);
        for workflow in SKILL_WORKFLOWS {
            if workflow not in known and existsSync(skillFile(skillsDir, workflow)) {
                return True;
            }
        }
    }
    return False;
}
