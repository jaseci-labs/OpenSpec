import from "diff" { formatPatch, OMIT_HEADERS, structuredPatch }

def extractRequirementBlock(specContent: str, requirementName: str) -> any {
    target = normalizeRequirementName(requirementName);
    foldedTarget = foldRequirementName(target);
    folded: any = JsNull;
    for block in extractRequirementsSection(specContent).bodyBlocks {
        name = normalizeRequirementName(block.name);
        if name == target {
            return rec(raw=block.raw, name=name, exact=True);
        }
        if folded is JsNull and foldRequirementName(name) == foldedTarget {
            folded = rec(raw=block.raw, name=name, exact=False);
        }
    }
    return folded;
}

def:priv withNewline(s: any) -> str {
    return s if s.endsWith("\n") else s + "\n";
}

def diffRequirementBlock(baseBlock: any, deltaBlock: str, label: str) -> str {
    base = withNewline("" if missing(baseBlock) else baseBlock);
    return formatPatch(
        structuredPatch(label, label, base, withNewline(deltaBlock)), OMIT_HEADERS
    ).trimEnd();
}

def:priv renameEntries(renames: any) -> list[any] {
    names: dict[str, str] = {};
    for r in renames {
        was = foldRequirementName(r["from"]);
        original = names.pop(was, None) ?? normalizeRequirementName(r["from"]);
        names[foldRequirementName(r["to"])] = original;
    }
    return [[k, v] for (k, v) in names.items()];
}

glob buildRenameMap: any = new(
    globalThis.Function, "entries", "return renames => new Map(entries(renames))"
)(renameEntries);
