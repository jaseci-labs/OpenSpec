glob SCENARIO_HEADER: any = rx("^####\\s+");

def hasScenarioBody(body: any) -> bool {
    return body.trim() != "";
}

def containsShallOrMust(text: str) -> bool {
    return found(text, "\\b(SHALL|MUST)\\b");
}

def extractRequirementBody(bodyLines: any) -> str {
    mask = buildCodeFenceMask(bodyLines);
    captured: list[str] = [];
    metadata: list[str] = [];
    for (i, line) in enumerate(bodyLines) {
        if mask[i] {
            continue;
        }
        if found(line, "^#{1,6}\\s") {
            break;
        }
        trimmed = line.trim();
        if trimmed {
            (metadata if found(trimmed, "^\\*\\*[^*]+\\*\\*:") else captured).append(trimmed);
        }
    }
    return "\n".join(captured or metadata);
}

def extractRequirementText(headerTitle: any, bodyLines: any) -> str {
    return extractRequirementBody(bodyLines) or headerTitle.trim();
}

def:priv readScenarioBodies(bodyLines: any) -> list[str] {
    mask = buildCodeFenceMask(bodyLines);
    bodies: list[str] = [];
    n = len(bodyLines);
    for i in range(n) {
        if mask[i] or not SCENARIO_HEADER.test(bodyLines[i]) {
            continue;
        }
        end = i + 1;
        while end < n and (mask[end] or not found(bodyLines[end], "^#{1,4}\\s")) {
            end += 1;
        }
        bodies.append("\n".join(bodyLines[i + 1:end]));
    }
    return bodies;
}

def countScenarios(bodyLines: any) -> int {
    return len([b for b in readScenarioBodies(bodyLines) if hasScenarioBody(b)]);
}

def countEmptyScenarios(bodyLines: any) -> int {
    return len([b for b in readScenarioBodies(bodyLines) if not hasScenarioBody(b)]);
}

def:priv hasStep(lines: list[str], words: str) -> bool {
    return any([
        found(l, f"(?:\\*\\*|__)(?:{words}):?(?:\\*\\*|__)", "i") or found(l, f"\\b(?:{words})\\b")
        for l in lines
    ]);
}

def scenarioStepCoverage(scenarioRaw: str) -> any {
    lines = sub(scenarioRaw, "\\r\\n?", "\n").split("\n");
    mask = buildCodeFenceMask(lines);
    steps = [l for (i, l) in enumerate(lines) if i > 0 and not mask[i]];
    return rec(hasTrigger=hasStep(steps, "WHEN|GIVEN"), hasOutcome=hasStep(steps, "THEN"));
}
