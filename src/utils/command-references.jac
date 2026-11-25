glob:priv COMMAND_TO_SKILL_NAME: dict[str, str] = {
              "explore": "openspec-explore",
              "new": "openspec-new-change",
              "continue": "openspec-continue-change",
              "apply": "openspec-apply-change",
              "update": "openspec-update-change",
              "ff": "openspec-ff-change",
              "sync": "openspec-sync-specs",
              "archive": "openspec-archive-change",
              "bulk-archive": "openspec-bulk-archive-change",
              "verify": "openspec-verify-change",
              "onboard": "openspec-onboard",
              "propose": "openspec-propose",
              "router": "openspec",
          },
          SKILL_INVOCATION_PREFIX: dict[str, str] = {"kimi": "/skill:", "codex": "$"},
          NATURAL_LANGUAGE_SKILL_TOOLS: list[str] = ["gsd", "rovodev", "codeassistant"];

def:priv replaceKnown(text: str, spell: any) -> str {
    return sub(
        text,
        "/opsx:([a-z-]+)",
        lambda (whole: str, commandId: str) -> str {
            spell(commandId, COMMAND_TO_SKILL_NAME[commandId])
                if commandId in COMMAND_TO_SKILL_NAME
                else whole
        },
    );
}

def:priv replaceCommandsWithSkillReferences(text: str, prefix: str) -> str {
    return replaceKnown(text, lambda (id: str, skill: str) -> str { prefix + skill });
}

def:priv replaceCommandsWithNaturalLanguageSkillReferences(text: str) -> str {
    return replaceKnown(text, lambda (id: str, skill: str) -> str { f"the {skill} skill" });
}

def transformCommandInvocations(text: str, invocation: any) -> str {
    return replaceKnown(
        text, lambda (id: str, skill: str) -> str { formatCommandInvocation(invocation, id) }
    );
}

def usesNaturalLanguageSkillReferences(toolId: str) -> bool {
    return toolId in NATURAL_LANGUAGE_SKILL_TOOLS;
}

def transformToCodexCompatibleSkillReferences(text: str) -> str {
    return replaceKnown(
        text, lambda (id: str, skill: str) -> str { f"${skill} (Codex) or /{skill} (other agents)" }
    );
}

def transformToSharedSkillReferences(text: str) -> str {
    return replaceCommandsWithSkillReferences(text, "");
}

def transformToSkillReferences(text: str) -> str {
    return replaceCommandsWithSkillReferences(text, "/");
}

def getSkillReferenceTransformer(toolId: str) -> any {
    if usesNaturalLanguageSkillReferences(toolId) {
        return replaceCommandsWithNaturalLanguageSkillReferences;
    }
    if toolId not in SKILL_INVOCATION_PREFIX {
        return transformToSkillReferences;
    }
    prefix = SKILL_INVOCATION_PREFIX[toolId];
    return lambda (text: str) -> str { replaceCommandsWithSkillReferences(text, prefix) };
}

def getTransformerForTool(toolId: str, delivery: any, capability: any, invocation: any) -> any {
    return transformToCodexCompatibleSkillReferences
        if toolId == "codex"
        else getSkillReferenceTransformer(toolId);
}
