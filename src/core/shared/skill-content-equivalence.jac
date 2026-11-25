def:priv toLegacyCodexReferences(content: str) -> str {
    return sub(
        content,
        "\\$(openspec-[a-z0-9-]+) \\(Codex\\) or \\/\\1 \\(other agents\\)",
        lambda (whole: str, skillName: str) -> str {
            f"${skillName}" if skillName in OPENSPEC_SKILL_NAMES else whole
        },
    );
}

def isLegacyCodexSkillEquivalentToCurrent(legacyContent: str, currentContent: str) -> bool {
    legacy = normalizeGeneratedContent(legacyContent);
    current = normalizeGeneratedContent(currentContent);
    return legacy == current or legacy == toLegacyCodexReferences(current);
}

def isRedundantLegacyCopy(legacyContent: str, currentContent: str, isSkillFile: bool) -> bool {
    return legacyContent == currentContent
        or (isSkillFile and isLegacyCodexSkillEquivalentToCurrent(legacyContent, currentContent))
        or isReleasedGeneratedContent(legacyContent);
}
