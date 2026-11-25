import from "node:path" { default as path }

def:priv hasSkill(view: any, dir: str) -> bool {
    for name in SKILL_NAMES {
        if view.exists(path.join(dir, name, "SKILL.md")) {
            return True;
        }
    }
    return False;
}

def:priv hasOwnPath(projectPath: str, tool: any, listed: list[any], view: any) -> bool {
    paths: any = tool["detectionPaths"] or [];
    if not paths {
        return tool.skillsDir != SHARED_SKILLS_ROOT
            and view.isDirectory(path.join(projectPath, tool.skillsDir));
    }
    for p in paths {
        if tool.skillsDir == SHARED_SKILLS_ROOT
            and (p == SHARED_SKILLS_ROOT or p.startswith(f"{SHARED_SKILLS_ROOT}/skills"))
            or not view.exists(path.join(projectPath, p))
        {
            continue;
        }
        if not p.endswith("/skills")
            or not listed
            or tool.value in listed
            or hasSkill(view, path.join(projectPath, p))
        {
            return True;
        }
    }
    return False;
}

def:priv isAvailable(projectPath: str, tool: any, listed: list[any], view: any) -> bool {
    if not toolSupportsSkills(tool) {
        return False;
    }
    if tool["globalSkillsDir"] {
        return hasSkill(view, resolveToolSkillsDir(projectPath, tool));
    }
    return truthy(tool["skillsDir"])
        and (
            hasOwnPath(projectPath, tool, listed, view)
            or usesSharedSkills(tool)
                and tool.value in listed
                and isListedToolPresent(projectPath, tool.value, view)
        );
}

def getAvailableTools(projectPath: str, view: any = None) -> list[any] {
    view = view ?? DISK_VIEW;
    listed = readSkillToolList(projectPath, view);
    return [tool for tool in AI_TOOLS if isAvailable(projectPath, tool, listed, view)];
}
