import from "node:crypto" { createHash }

type SkillTemplateEntry = any;

type CommandTemplateEntry = any;

def:priv only(all: any, workflowFilter: any, key: str) -> any {
    return all if missing(workflowFilter) else [e for e in all if e[key] in workflowFilter];
}

def getSkillTemplates(workflowFilter: any = None) -> any {
    return only(
        [
            rec(template=make(), dirName=dirName, workflowId=workflowId)
            for (make, dirName, workflowId) in [
                (getExploreSkillTemplate, "openspec-explore", "explore"),
                (getNewChangeSkillTemplate, "openspec-new-change", "new"),
                (getContinueChangeSkillTemplate, "openspec-continue-change", "continue"),
                (getApplyChangeSkillTemplate, "openspec-apply-change", "apply"),
                (getUpdateChangeSkillTemplate, "openspec-update-change", "update"),
                (getFfChangeSkillTemplate, "openspec-ff-change", "ff"),
                (getSyncSpecsSkillTemplate, "openspec-sync-specs", "sync"),
                (getArchiveChangeSkillTemplate, "openspec-archive-change", "archive"),
                (getBulkArchiveChangeSkillTemplate, "openspec-bulk-archive-change", "bulk-archive"),
                (getVerifyChangeSkillTemplate, "openspec-verify-change", "verify"),
                (getOnboardSkillTemplate, "openspec-onboard", "onboard"),
                (getOpsxProposeSkillTemplate, "openspec-propose", "propose"),
                (getRouterSkillTemplate, ROUTER_SKILL_NAME, "router"),
            ]
        ],
        workflowFilter,
        "workflowId",
    );
}

def stripVolatileFrontmatter(content: str) -> str {
    return sub(content, "^ {2}generatedBy: .*\\n", "", "m");
}

def getCommandTemplates(workflowFilter: any = None) -> any {
    return only(
        [
            rec(template=make(), id=id)
            for (make, id) in [
                (getOpsxExploreCommandTemplate, "explore"),
                (getOpsxNewCommandTemplate, "new"),
                (getOpsxContinueCommandTemplate, "continue"),
                (getOpsxApplyCommandTemplate, "apply"),
                (getOpsxUpdateCommandTemplate, "update"),
                (getOpsxFfCommandTemplate, "ff"),
                (getOpsxSyncCommandTemplate, "sync"),
                (getOpsxArchiveCommandTemplate, "archive"),
                (getOpsxBulkArchiveCommandTemplate, "bulk-archive"),
                (getOpsxVerifyCommandTemplate, "verify"),
                (getOpsxOnboardCommandTemplate, "onboard"),
                (getOpsxProposeCommandTemplate, "propose"),
            ]
        ],
        workflowFilter,
        "id",
    );
}

def getCommandContents(workflowFilter: any = None) -> any {
    return [
        rec(
            id=e.id,
            name=e.template.name,
            description=e.template.description,
            category=e.template.category,
            tags=e.template.tags,
            body=e.template.content,
        )
        for e in getCommandTemplates(workflowFilter)
    ];
}

def generateSkillContent(
    template: any, generatedByVersion: str, transformInstructions: any = None
) -> str {
    refs: any = at(template, "metadata", "references");
    refLine = f'  references: "{refs}"\n' if refs else "";
    return f"""---
name: {template.name}
description: {template.description}
allowed-tools: {OPENSPEC_CLI_ALLOWED_TOOLS}
license: {template["license"] or "MIT"}
compatibility: {template["compatibility"] or "Requires openspec CLI."}
metadata:
  author: {at(template, "metadata", "author") or "openspec"}
  version: "{at(template, "metadata", "version") or "1.0"}"
  generatedBy: "{generatedByVersion}"
{refLine}---

{transformInstructions(template.instructions) if transformInstructions else template.instructions}
""";
}

def:priv skillFiles(
    template: any, generatedByVersion: str, transformInstructions: any = None
) -> any {
    refs: any = globalThis.Object.entries(template["references"] ?? rec());
    if not refs {
        return [
            ["SKILL.md", generateSkillContent(template, generatedByVersion, transformInstructions)],
        ];
    }
    digest = createHash("sha256");
    files: list[any] = [];
    for (file, text) in refs {
        content = transformInstructions(text) if transformInstructions else text;
        files.append([f"references/{file}", content]);
        digest.update(f"{file}\n{content}\n");
    }
    skill = merge(
        template,
        rec(metadata=merge(template["metadata"], rec(references=digest.digest("hex")[:12]))),
    );
    return [
        ["SKILL.md", generateSkillContent(skill, generatedByVersion, transformInstructions)],
        *files,
    ];
}

glob generateSkillFiles: any = new(globalThis.Function, "f", "return (...a) => new Map(f(...a))")(
    skillFiles
);
