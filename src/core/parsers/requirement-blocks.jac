type RequirementBlock = any;

type RequirementsSectionParts = any;

type DeltaPlan = any;

glob REQUIREMENTS_SECTION_HEADER_REGEX: any = rx("^##\\s+Requirements(?:[ \\t]+#+)?\\s*$", "i");

glob:priv REQ: str = "^###\\s*Requirement:\\s*(.+)\\s*$",
          TOP: str = "^##\\s+",
          DELTA_TITLES: list[str] = [
              "added requirements",
              "modified requirements",
              "removed requirements",
              "renamed requirements",
          ];

def stripClosingSequence(title: str) -> str {
    return trim(sub(title, "[ \\t]+#+[ \\t]*$", "", ""));
}

def normalizeRequirementName(name: str) -> str {
    return stripClosingSequence(name);
}

def foldRequirementName(name: str) -> str {
    return sub(stripClosingSequence(name).lower(), "\\s+", " ");
}

def:priv normalizeLineEndings(content: str) -> str {
    return sub(sub(content, "^\\uFEFF", "", ""), "\\r\\n?", "\n");
}

def:priv firstLine(lines: any, mask: any, pattern: str, flags: str = "", start: int = 0) -> int {
    for i in range(start, len(lines)) {
        if not mask[i] and found(lines[i], pattern, flags) {
            return i;
        }
    }
    return -1;
}

def:priv readBlocks(
    lines: any, mask: any, sink: any = None, section: str = "", start: int = 0
) -> list[any] {
    starts: list[int] = [];
    ends: list[int] = [];
    live = False;
    for i in range(len(lines)) {
        line = lines[i];
        if mask[i] {
            if live {
                ends[-1] = i + 1;
            }
            continue;
        }
        if found(line, REQ, "i") {
            starts.append(i);
            ends.append(i + 1);
            live = True;
            continue;
        }
        if found(line, TOP) {
            live = False;
        }
        if live {
            ends[-1] = i + 1;
        }
        h3 = JsNull if sink is None else matchOf(line, "^###\\s+(.+?)\\s*$");
        if h3 {
            sink.append(rec(header=trim(h3[1]), section=section, line=start + i));
        }
    }
    return [
        rec(
            headerLine=lines[a],
            name=stripClosingSequence(matchOf(lines[a], REQ, "i")[1]),
            raw=rtrim("\n".join(lines[a:b])),
        )
        for (a, b) in zip(starts, ends)
    ];
}

def extractRequirementsSection(content: str) -> any {
    lines = normalizeLineEndings(content).split("\n");
    mask = buildCodeFenceMask(lines);
    head = firstLine(lines, mask, REQUIREMENTS_SECTION_HEADER_REGEX.source, "i");
    if head == -1 {
        before = rtrim(content);
        return rec(
            before=before + "\n\n" if before else "",
            headerLine="## Requirements",
            preamble="",
            bodyBlocks=[],
            after="\n",
        );
    }
    end = firstLine(lines, mask, TOP, "", head + 1);
    end = len(lines) if end == -1 else end;
    body = lines[head + 1:end];
    bodyMask = mask[head + 1:end];
    first = firstLine(body, bodyMask, REQ, "i");
    before = "\n".join(lines[:head]);
    after = "\n".join(lines[end:]);
    return rec(
        before=before + "\n" if rtrim(before) else before,
        headerLine=lines[head],
        preamble=rtrim("\n".join(body if first == -1 else body[:first])),
        bodyBlocks=readBlocks(body, bodyMask),
        after=after if after.startswith("\n") else "\n" + after,
    );
}

def:priv maskHtmlComments(lines: any, mask: any) -> list[str] {
    comments = sub(
        "\n".join(["" if mask[i] else lines[i] for i in range(len(lines))]),
        "<!--[\\s\\S]*?(?:--!?>|$)",
        lambda (m: str) -> str { sub(m, "[^\\n]", " ") },
    ).split("\n");
    return [lines[i] if mask[i] else comments[i] for i in range(len(lines))];
}

def:priv splitSections(lines: any, mask: any) -> list[any] {
    heads: list[any] = [];
    for i in range(len(lines)) {
        line = lines[i];
        m = JsNull if mask[i] else matchOf(line, "^##\\s+(.+)$");
        if m {
            heads.append((stripClosingSequence(m[1]), i));
        }
    }
    ends = [h[1] for h in heads[1:]] + [len(lines)];
    return [
        (h[0], lines[h[1] + 1:ends[k]], mask[h[1] + 1:ends[k]], h[1] + 2)
        for (k, h) in enumerate(heads)
    ];
}

def:priv isDelta(section: any) -> bool {
    return not missing(section) and section.toLowerCase() in DELTA_TITLES;
}

def isUnrecognizedDeltaSection(section: any) -> bool {
    return not missing(section)
        and found(section, "\\brequirements?$", "i")
        and not isDelta(section);
}

def:priv findOrphans(lines: any, mask: any) -> list[any] {
    orphans: list[any] = [];
    masked = maskHtmlComments(lines, mask);
    section: any = JsNull;
    for i in range(len(lines)) {
        line = lines[i];
        if mask[i] {
            continue;
        }
        head = matchOf(line, "^##\\s+(.+)$");
        if head {
            section = stripClosingSequence(head[1]);
            continue;
        }
        m = JsNull if isDelta(section) else matchOf(masked[i], REQ, "i");
        if m {
            orphans.append(rec(name=stripClosingSequence(m[1]), section=section, line=i + 1));
        }
    }
    return orphans;
}

def describeUnappliedContent(content: any, sentenceStart: bool = False) -> str {
    s = content.section;
    text: any = 'text above the first "## " section'
        if s is JsNull
        else (
            f'text before the first requirement in "## {s}"' if isDelta(s) else f'section "## {s}"'
        );
    return text.charAt(0).toUpperCase() + text.slice(1) if sentenceStart else text;
}

def findFrontmatterEnd(lines: any) -> int {
    if lines[0].trimEnd() != "---" {
        return 0;
    }
    sawKey = False;
    sawComment = False;
    for i in range(1, len(lines)) {
        line = lines[i];
        if found(line, "^#{2,6}(?:\\s|$)") or found(line, REQ, "i") {
            return 0;
        }
        if line.trimEnd() == "---" {
            return i + 1 if sawKey or not sawComment else 0;
        }
        if sawKey or not line.trim() {
            continue;
        }
        if line.trimStart().startsWith("#") {
            sawComment = True;
            continue;
        }
        if not found(line, "^(?:\"[^\"]+\"|'[^']+'|[\\p{L}\\p{N}_.-]+)\\s*:(?:\\s|$)", "u") {
            return 0;
        }
        sawKey = True;
    }
    return 0;
}

def:priv findUnapplied(lines: any, mask: any, sections: list[any]) -> list[any] {
    masked = maskHtmlComments(lines, mask);
    def firstText(a: int, b: int, ignore: str = "") -> int {
        for i in range(a, b) {
            if trim(masked[i]) and not (ignore and found(masked[i], ignore)) {
                return i;
            }
        }
        return -1;
    }
    out: list[any] = [];
    preamble = firstText(0, sections[0][3] - 2 if sections else len(lines), "^#\\s");
    if preamble != -1 {
        out.append(rec(section=JsNull, line=preamble + 1));
    }
    for (title, body, bodyMask, bodyStart) in sections {
        folded = title.lower();
        start = bodyStart - 1;
        if folded in DELTA_TITLES[:2] {
            block = firstLine(body, bodyMask, REQ, "i");
            first = firstText(start, start + (len(body) if block == -1 else block), "^###\\s");
            if first != -1 {
                out.append(rec(section=title, line=first + 1));
            }
        } elif folded not in DELTA_TITLES
            and not (folded == "purpose" and trim(masked[start - 1]))
            and firstText(start, start + len(body)) != -1
        {
            out.append(rec(section=title, line=start));
        }
    }
    return out;
}

def:priv removedNames(lines: any, mask: any) -> list[str] {
    names: list[str] = [];
    for i in range(len(lines)) {
        line = lines[i];
        m = JsNull
            if mask[i]
            else (
                matchOf(line, REQ, "i")
                or matchOf(line, "^\\s*[-*+]\\s*`?###\\s*Requirement:\\s*(.+?)`?\\s*$")
            );
        if m {
            names.append(stripClosingSequence(m[1]));
        }
    }
    return names;
}

def:priv renamedPairs(lines: any, mask: any, start: int, unpaired: list[any]) -> list[any] {
    pairs: list[any] = [];
    pending: any = None;
    for i in range(len(lines)) {
        line = lines[i];
        m = JsNull
            if mask[i]
            else matchOf(
                line, "^\\s*[-*+]?\\s*(FROM|TO):\\s*`?###\\s*Requirement:\\s*(.+?)`?\\s*$"
            );
        if not m {
            continue;
        }
        name = stripClosingSequence(m[2]);
        if m[1] == "FROM" {
            if pending is not None {
                unpaired.append(pending);
            }
            pending = rec(side="FROM", name=name, line=start + i);
        } elif pending is None {
            unpaired.append(rec(side="TO", name=name, line=start + i));
        } else {
            pairs.append(globalThis.Object.fromEntries([["from", pending.name], ["to", name]]));
            pending = None;
        }
    }
    if pending is not None {
        unpaired.append(pending);
    }
    return pairs;
}

def parseDeltaSpec(content: str) -> any {
    lines = normalizeLineEndings(content).split("\n");
    frontmatterEnd = findFrontmatterEnd(lines);
    for i in range(frontmatterEnd) {
        lines[i] = "";
    }
    mask = buildCodeFenceMask(lines);
    sections = splitSections(lines, mask);
    skipped: list[any] = [];
    unpaired: list[any] = [];
    def blocks(hits: list[any], sink: any = None) -> list[any] {
        return [b for s in hits for b in readBlocks(s[1], s[2], sink, hits[0][0], s[3])];
    }
    (added, modified, removed, renamed) = [
        [s for s in sections if s[0].lower() == t]
        for t in DELTA_TITLES
    ];
    return rec(
        added=blocks(added, skipped),
        modified=blocks(modified, skipped),
        removed=[n for s in removed for n in removedNames(s[1], s[2])],
        removedBlocks=blocks(removed),
        renamed=[p for s in renamed for p in renamedPairs(s[1], s[2], s[3], unpaired)],
        unpairedRenames=sorted(unpaired, key=lambda (u: any) -> int { u.line }),
        orphanedRequirements=findOrphans(lines, mask),
        unappliedContent=findUnapplied(lines, mask, sections),
        hasFrontmatter=frontmatterEnd > 0,
        skippedHeaders=sorted(skipped, key=lambda (h: any) -> int { h.line }),
        sectionPresence=rec(
            added=len(added) > 0,
            modified=len(modified) > 0,
            removed=len(removed) > 0,
            renamed=len(renamed) > 0,
        ),
    );
}

def:priv unmatched(names: list[str], against: list[str]) -> list[str] {
    left = list(against);
    out: list[str] = [];
    for name in names {
        if name in left {
            left.remove(name);
        } else {
            out.append(name);
        }
    }
    return out;
}

def diffScenarioNames(current: any, incoming: any) -> any {
    was = [s.name for s in parseScenarioBlocks(current.raw)];
    now = [s.name for s in parseScenarioBlocks(incoming.raw)];
    return rec(
        missing=unmatched(was, now),
        added=unmatched(now, was),
        currentCount=len(was),
        incomingCount=len(now),
    );
}

def findMissingCurrentScenarios(current: any, incoming: any) -> list[str] {
    return diffScenarioNames(current, incoming).missing;
}

def describeScenarioBalance(diff: any) -> str {
    def count(value: int) -> str {
        return f"{value} {'scenario' if value == 1 else 'scenarios'}";
    }
    scale = f"The modified block has {count(diff.incomingCount)}; the current spec has {count(diff.currentCount)}.";
    more = len(diff.added) - 3;
    if not diff.added {
        return f"{scale} It adds none.";
    }
    names = ", ".join([f'"{name}"' for name in diff.added[:3]])
        + (f" and {more} more" if more > 0 else "");
    return f"{scale} It adds {count(len(diff.added))} not in the current spec: {names}.";
}

def scenarioNameFromHeaderText(headerText: str) -> str {
    return trim(sub(sub(headerText, "[ \\t]+#+[ \\t]*$", "", ""), "^Scenario:\\s*", "", "i"));
}

def isScenarioLabeledHeader(headerLine: str) -> bool {
    return found(sub(headerLine, SCENARIO_HEADER.source, "", ""), "^Scenario:\\s*", "i");
}

def parseScenarioBlocks(requirementRaw: str) -> list[any] {
    lines = sub(requirementRaw, "\\r\\n?", "\n").split("\n");
    mask = buildCodeFenceMask(lines);
    starts = [i for i in range(len(lines)) if not mask[i] and SCENARIO_HEADER.test(lines[i])];
    return [
        rec(
            name=scenarioNameFromHeaderText(sub(lines[a], SCENARIO_HEADER.source, "", "")),
            raw=rtrim("\n".join(lines[a:b])),
        )
        for (a, b) in zip(starts, starts[1:] + [len(lines)])
    ];
}
