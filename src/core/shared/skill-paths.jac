import from "node:os" { homedir }
import from "node:path" { join }
import from "node:process" { default as process }

type SkillCapableTool = any;

glob SHARED_SKILLS_ROOT: str = ".agents";

def toolSupportsSkills(tool: any) -> bool {
    return truthy(tool["skillsDir"] or tool["globalSkillsDir"]);
}

def getSkillCapableTools -> list[any] {
    return [t for t in AI_TOOLS if toolSupportsSkills(t)];
}

def hasGlobalSkillTarget(tool: any) -> bool {
    return truthy(tool["globalSkillsDir"]);
}

def resolveToolSkillsDir(projectRoot: str, tool: any, options: any = None) -> str {
    if tool["globalSkillsDir"] {
        home = at(options, "homeDir");
        if missing(home) {
            home = process.env["USERPROFILE"] ?? process.env["HOME"] ?? homedir();
        }
        return join(home, tool.globalSkillsDir, "skills");
    }
    if tool["skillsDir"] {
        return resolveSharedSkillsDir(projectRoot);
    }
    raise new(globalThis.Error, f"Tool '{tool.value}' does not support skill generation.");
}

def usesSharedSkills(tool: any) -> bool {
    return truthy(tool["skillsDir"]) and not tool["globalSkillsDir"];
}

def resolveSharedSkillsDir(projectRoot: str) -> str {
    return join(projectRoot, SHARED_SKILLS_ROOT, "skills");
}

def resolveSkillLinkDir(projectRoot: str, tool: any) -> any {
    if usesSharedSkills(tool) and SKILL_LINKED_TOOL_IDS.has(tool.value) {
        return join(projectRoot, installerAgent(tool.value).projectSkillsDir);
    }
    return None;
}

def resolveFormerOwnSkillsDir(projectRoot: str, tool: any) -> any {
    if usesSharedSkills(tool) and tool.skillsDir != SHARED_SKILLS_ROOT {
        return join(projectRoot, tool.skillsDir, "skills");
    }
    return None;
}
