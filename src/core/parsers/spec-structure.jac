def findMainSpecStructureIssues(content: str) -> list[any] {
    lines = stripFencedCodeBlocksPreservingLines(sub(content, "\\r\\n?", "\n")).split("\n");
    issues: list[any] = [];
    seen: dict[str, int] = {};
    head = -1;
    end = len(lines);
    for i in range(len(lines)) {
        line = lines[i];
        if head == -1 and REQUIREMENTS_SECTION_HEADER_REGEX.test(line) {
            head = i;
        } elif head != -1 and found(line, "^##\\s+") {
            end = i;
            break;
        }
    }
    for i in range(len(lines)) {
        line = lines[i];
        text: any = line;
        trimmed = text.trim();
        if not trimmed {
            continue;
        }
        m = matchOf(line, "^###\\s*Requirement:\\s*(.+)\\s*$", "i");
        kind = "duplicate-requirement";
        message = "";
        if found(
            line, "^##\\s+(ADDED|MODIFIED|REMOVED|RENAMED)\\s+Requirements(?:[ \\t]+#+)?\\s*$", "i"
        ) {
            kind = "delta-header";
            message = f'Main spec contains delta header "{trimmed}". Delta headers are only valid inside openspec/changes/<name>/specs/<capability-path>/spec.md and truncate the parsed ## Requirements section.';
        } elif not m {
            continue;
        } elif not (head < i < end and head != -1) {
            kind = "requirement-outside-requirements";
            message = f'Requirement header "{trimmed}" appears outside the main ## Requirements section. Main specs only parse requirements inside that section, so this requirement is currently invisible to validate, list, and archive.';
        } else {
            name = normalizeRequirementName(m[1]);
            if name not in seen {
                seen[name] = i + 1;
                continue;
            }
            message = f'Requirement header "{trimmed}" duplicates the requirement declared on line {seen[name]}. Requirement names must be unique so spec updates cannot discard one block while updating another.';
        }
        issues.append(rec(kind=kind, line=i + 1, header=trimmed, message=message));
    }
    return issues;
}

def stripFencedCodeBlocksPreservingLines(content: str) -> str {
    lines = content.split("\n");
    mask = buildCodeFenceMask(lines);
    return "\n".join(["" if mask[i] else lines[i] for i in range(len(lines))]);
}
