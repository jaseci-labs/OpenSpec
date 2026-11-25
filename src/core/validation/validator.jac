import from "fs" { readFileSync, promises as fs }
import from "path" { default as path }

glob:priv M: any = VALIDATION_MESSAGES,
          UNUSABLE: list[str] = ["EACCES", "EPERM", "EISDIR", "ELOOP", "ENAMETOOLONG"],
          SECTIONS: list[tuple[str, str]] = [
              ("added", "## ADDED Requirements"),
              ("modified", "## MODIFIED Requirements"),
              ("removed", "## REMOVED Requirements"),
              ("renamed", "## RENAMED Requirements"),
          ];

def:priv issue(level: str, where: str, message: str, line: any = None) -> any {
    out = rec(level=level, path=where);
    if line is not None {
        out.line = line;
    }
    out.message = message;
    return out;
}

def:priv errorText(error: any, fallback: any = None) -> str {
    err = js_error(error);
    if globalThis.Error.prototype.isPrototypeOf(err) {
        return err.message;
    }
    return fallback ?? globalThis.String(err);
}

def:priv codeOf(error: any) -> any {
    return at(js_error(error), "code");
}

def:priv remember(seen: list[str], key: str) -> bool {
    if key in seen {
        return False;
    }
    seen.append(key);
    return True;
}

def:priv enrich(base: any) -> str {
    msg: any = base.trim();
    if msg == M.CHANGE_NO_DELTAS {
        return f"{msg}. {M.GUIDE_NO_DELTAS}";
    }
    if "Spec must have a Purpose section" in msg or "Spec must have a Requirements section" in msg {
        return f"{msg}. {M.GUIDE_MISSING_SPEC_SECTIONS}";
    }
    if "Change must have a Why section" in msg or "Change must have a What Changes section" in msg {
        return f"{msg}. {M.GUIDE_MISSING_CHANGE_SECTIONS}";
    }
    return msg;
}

def:priv topLevelIssue(error: any) -> any {
    return issue("ERROR", "file", enrich(errorText(error, "Unknown error")));
}

def:priv nameFromPath(filePath: str) -> str {
    parts = FileSystemUtils.toPosixPath(filePath).split("/");
    for i in range(len(parts) - 2, -1, -1) {
        if parts[i] in ["specs", "changes"] {
            return parts[i + 1];
        }
    }
    fileName = parts[-1];
    dot = fileName.rfind(".");
    return fileName[:dot] if dot > 0 else fileName;
}

def:priv zodIssues(error: any) -> list[any] {
    return [
        issue(
            "ERROR",
            ".".join([globalThis.String(p) for p in e.path]),
            f"{e.message}. {M.GUIDE_NO_DELTAS}" if e.message == M.CHANGE_NO_DELTAS else e.message,
        )
        for e in error.issues
    ];
}

def:priv markerIssues(marker: any) -> list[any] {
    reason = marker["invalidReason"];
    return [issue("ERROR", METADATA_FILENAME, f"{M.CHANGE_SKIP_SPECS_INVALID_METADATA} ({reason})")]
        if reason
        else [];
}

def:priv requirementText(raw: any) -> any {
    return extractRequirementBody(raw.split("\n")[1:]) or None;
}

def:priv shallMessage(prefix: str, name: str, guidance: bool = False) -> str {
    base = f"{prefix} {'should' if guidance else 'must'} contain SHALL or MUST";
    suffix = " (RFC 2119 best practice for English specs)" if guidance else "";
    if containsShallOrMust(name) {
        return f'{base} in the requirement body, not only in the header. Move the SHALL/MUST statement to the line immediately after the "### Requirement: ..." header.{suffix}';
    }
    return base + suffix;
}

def:priv keywordIssues(
    text: any, label: str, name: str, where: str, bare: bool = False
) -> list[any] {
    if not text {
        return [
            issue(
                "ERROR",
                where,
                f"{label} is missing requirement text"
                    if bare and not containsShallOrMust(name)
                    else shallMessage(label, name),
            ),
        ];
    }
    return []
        if containsShallOrMust(text)
        else [issue("WARNING", where, shallMessage(label, name, True))];
}

def:priv stepIssues(raw: str, label: str, where: str) -> list[any] {
    issues: list[any] = [];
    for scenario in parseScenarioBlocks(raw) {
        lines = scenario.raw.split("\n");
        if not hasScenarioBody("\n".join(lines[1:])) or not isScenarioLabeledHeader(lines[0]) {
            continue;
        }
        steps = scenarioStepCoverage(scenario.raw);
        lacking = [
            part
            for (ok, part) in [
                (steps.hasTrigger, "a WHEN/GIVEN step"),
                (steps.hasOutcome, "a THEN step"),
            ]
            if not ok
        ];
        if lacking {
            issues.append(
                issue(
                    "WARNING",
                    where,
                    f'{label}: scenario "{scenario.name}" is missing {" and ".join(lacking)}. A scenario needs a trigger and an outcome, e.g. "- **WHEN** an invoice is voided" and "- **THEN** a credit note is issued".',
                ),
            );
        }
    }
    return issues;
}

def:priv specRules(spec: any, content: str) -> list[any] {
    issues = [
        issue("ERROR", "file", s.message, s.line)
        for s in findMainSpecStructureIssues(content)
    ];
    placeholder = findPurposePlaceholderIssue(spec.overview, content);
    if not missing(placeholder) {
        issues.append(issue("WARNING", "overview", M.PURPOSE_IS_PLACEHOLDER, placeholder.line));
    } elif len(spec.overview) < MIN_PURPOSE_LENGTH {
        issues.append(issue("WARNING", "overview", M.PURPOSE_TOO_BRIEF));
    }
    for (index, req) in enumerate(spec.requirements) {
        if len(req.text) > MAX_REQUIREMENT_TEXT_LENGTH {
            issues.append(issue("WARNING", f"requirements[{index}]", M.REQUIREMENT_TOO_LONG));
        }
        if len(req.scenarios) == 0 {
            issues.append(
                issue(
                    "WARNING",
                    f"requirements[{index}].scenarios",
                    f"{M.REQUIREMENT_NO_SCENARIOS}. {M.GUIDE_SCENARIO_FORMAT}",
                ),
            );
        }
    }
    for (index, block) in enumerate(extractRequirementsSection(content).bodyBlocks) {
        label = f'Requirement "{block.name}"';
        issues.extend(
            keywordIssues(requirementText(block.raw), label, block.name, f"requirements[{index}]")
        );
        issues.extend(stepIssues(block.raw, label, f"requirements[{index}].scenarios"));
    }
    return issues;
}

def:priv specIssues(name: str, content: any, file: any = None) -> list[any] {
    issues: list[any] = [];
    try {
        text = readFileSync(file, "utf-8") if file is not None else content;
        spec = MarkdownParser(text).parseSpec(name);
        result = SpecSchema.safeParse(spec);
        if not result.success {
            issues.extend(zodIssues(result.error));
        }
        issues.extend(specRules(spec, text));
    } except Exception as e {
        issues.append(topLevelIssue(e));
    }
    return issues;
}

def:priv changeRules(change: any) -> list[any] {
    issues: list[any] = [];
    for (index, delta) in enumerate(change.deltas) {
        if not delta["description"] or len(delta.description) < 10 {
            issues.append(
                issue("WARNING", f"deltas[{index}].description", M.DELTA_DESCRIPTION_TOO_BRIEF)
            );
        }
        if delta.operation in ["ADDED", "MODIFIED"] and not delta["requirements"] {
            issues.append(
                issue(
                    "WARNING",
                    f"deltas[{index}].requirements",
                    f"{delta.operation} {M.DELTA_MISSING_REQUIREMENTS}",
                ),
            );
        }
    }
    return issues;
}

def:priv emptyScenarioHint(raw: any) -> str {
    if countEmptyScenarios(raw.split("\n")[1:]) == 0 {
        return "";
    }
    return ' (a scenario header with no body under it does not count; add its steps, e.g. "- **WHEN** ..." and "- **THEN** ...")';
}

def:priv planNotes(plan: any, entryPath: str) -> list[any] {
    issues: list[any] = [];
    for stray in plan.skippedHeaders {
        header = stray.header;
        issues.append(
            issue(
                "INFO",
                entryPath,
                f'Header "### {header}" in {stray.section} is missing a requirement name and is ignored by validation. Add a name, e.g. "### Requirement: <name>".'
                    if found(header, "^requirement:?$", "i")
                    else f'Header "### {header}" in {stray.section} is not a "### Requirement:" header and is ignored by validation. Use "### Requirement: {header}" if it should be validated as a requirement.',
                stray.line,
            ),
        );
    }
    for unpaired in plan.unpairedRenames {
        other = "TO" if unpaired.side == "FROM" else "FROM";
        issues.append(
            issue(
                "ERROR",
                entryPath,
                f'RENAMED {unpaired.side}: "{unpaired.name}" has no matching {other}: line. Write each rename as a FROM: line followed immediately by its TO: line.',
                unpaired.line,
            ),
        );
    }
    for orphan in plan.orphanedRequirements {
        where = f'under "## {orphan.section}"'
            if orphan.section
            else 'above the first "## " section';
        issues.append(
            issue(
                "ERROR" if isUnrecognizedDeltaSection(orphan.section) else "WARNING",
                entryPath,
                f'Requirement "{orphan.name}" is {where}, which is not a delta section, so it is ignored. Move it under "## ADDED Requirements", "## MODIFIED Requirements", "## REMOVED Requirements", or "## RENAMED Requirements".',
                orphan.line,
            ),
        );
    }
    for lost in plan.unappliedContent {
        issues.append(
            issue(
                "WARNING",
                entryPath,
                f"{describeUnappliedContent(lost, True)} is not carried into the main spec by archive. Move it into a requirement, or into proposal.md or design.md.",
                lost.line,
            ),
        );
    }
    return issues;
}

def:priv chase(blocks: dict[str, any], renamedFrom: dict[str, str], name: str) -> any {
    visited: list[str] = [];
    key: any = name;
    while key is not None and key not in visited {
        if key in blocks {
            return blocks[key];
        }
        visited.append(key);
        key = renamedFrom.get(key);
    }
    return None;
}

async def:priv mainSpecModifiedIssues(
    modified: any, renamed: any, mainSpecFile: str, entryPath: str, mainSpecRoot: str
) -> list[any] {
    assertDiscoveredSpecFile(mainSpecRoot, mainSpecFile);
    try {
        mainContent = await fs.readFile(mainSpecFile, "utf-8");
    } except Exception as e {
        code = codeOf(e);
        if not code or code not in UNUSABLE {
            return [];
        }
        return [
            issue(
                "ERROR",
                entryPath,
                f"Could not read {FileSystemUtils.toPosixPath(mainSpecFile)} to check the MODIFIED requirements against it ({code}). Archive reads the same file, so fix the file before archiving.",
            ),
        ];
    }
    blocks: dict[str, any] = {
        normalizeRequirementName(b.name): b
        for b in extractRequirementsSection(mainContent).bodyBlocks
    };
    renamedFrom: dict[str, str] = {
        normalizeRequirementName(p.to): normalizeRequirementName(p["from"])
        for p in renamed
    };
    renamedAway = [normalizeRequirementName(p["from"]) for p in renamed];
    issues: list[any] = [];
    for block in modified {
        key = normalizeRequirementName(block.name);
        current = None if key in renamedAway else chase(blocks, renamedFrom, key);
        if current is None {
            continue;
        }
        nextText = requirementText(block.raw);
        if nextText
            and len(nextText) > MAX_REQUIREMENT_TEXT_LENGTH
            and len(nextText) > len(requirementText(current.raw) or "")
        {
            issues.append(
                issue("WARNING", entryPath, f'MODIFIED "{block.name}": {M.REQUIREMENT_TOO_LONG}')
            );
        }
        diff = diffScenarioNames(current, block);
        if len(diff.missing) == 0 {
            continue;
        }
        names = ", ".join([f'"{n}"' for n in diff.missing]);
        issues.append(
            issue(
                "ERROR",
                entryPath,
                f'MODIFIED "{block.name}" omits scenario(s) the current spec still has: {names}. {describeScenarioBalance(diff)} Copy the omitted scenarios into the MODIFIED block (a MODIFIED requirement replaces the whole block, so archive refuses to drop them).',
            ),
        );
    }
    return issues;
}

async def:priv archiveBlockers(
    changeDir: str, mainSpecsDir: str, reported: list[any]
) -> list[any] {
    try {
        updates = await findSpecUpdates(changeDir, mainSpecsDir);
    } except Exception as e {
        return [issue("INFO", "specs", f"Could not check archive merge conflicts: {errorText(e)}")];
    }
    issues: list[any] = [];
    for update in updates {
        entryPath = FileSystemUtils.toPosixPath(f"{update.id}/spec.md");
        if entryPath in reported {
            continue;
        }
        try {
            await buildUpdatedSpec(update, path.basename(changeDir), rec(silent=True));
        } except Exception as e {
            if codeOf(e) is None {
                issues.append(
                    issue("INFO", entryPath, f"Archive would refuse this delta: {errorText(e)}")
                );
            }
        }
    }
    return issues;
}

def:priv taskDocumentPath(changeDir: str, file: str) -> str {
    relative: str = path.relative(
        FileSystemUtils.canonicalizeExistingPath(changeDir),
        FileSystemUtils.canonicalizeExistingPath(file),
    );
    if relative == "" or relative.startswith("..") or path.isAbsolute(relative) {
        return path.basename(file);
    }
    return FileSystemUtils.toPosixPath(relative);
}

def:priv usesBuiltInSpecDrivenSchema(changeDir: str, projectRoot: str) -> bool {
    try {
        schemaName = sub(resolveSchemaForChange(changeDir, None, projectRoot), "\\.ya?ml$", "", "");
        if schemaName != "spec-driven" {
            return False;
        }
        schemaDir = getSchemaDir(schemaName, projectRoot);
        return not missing(schemaDir)
            and FileSystemUtils.canonicalizeExistingPath(schemaDir)
                == FileSystemUtils.canonicalizeExistingPath(
                    path.join(getPackageSchemasDir(), "spec-driven")
                );
    } except Exception {
        return False;
    }
}

async def:priv taskFileIssues(changeDir: str, projectRoot: str) -> list[any] {
    try {
        tracked = resolveTaskFilesForChange(changeDir, projectRoot);
    } except Exception {
        return [];
    }
    documents: list[any] = [];
    unreadable = 0;
    for file in (tracked if len(tracked) > 0 else [path.join(changeDir, "tasks.md")]) {
        try {
            content = await fs.readFile(file, "utf-8");
        } except Exception as e {
            if codeOf(e) != "ENOENT" {
                unreadable += 1;
            }
            continue;
        }
        documents.append(rec(path=taskDocumentPath(changeDir, file), content=content));
    }
    globalThis.Array.prototype.sort.call(
        documents, lambda (a: any, b: any) -> int { a.path.localeCompare(b.path) }
    );
    raw: list[any] = [];
    if len(tracked) > 0 and unreadable == 0 {
        raw.extend(findMissingTaskCheckboxIssues(documents));
    }
    if usesBuiltInSpecDrivenSchema(changeDir, projectRoot) {
        raw.extend(findTaskNumberingIssues(documents));
    }
    return [rec(level="WARNING", path=i.path, line=i["line"], message=i.message) for i in raw];
}

async def:priv deltaSpecIssues(changeDir: str, options: any) -> list[any] {
    issues: list[any] = [];
    specsDir = path.join(changeDir, "specs");
    mainSpecsDir = at(options, "mainSpecsDir");
    totalDeltas = 0;
    hasRootLevelSpec = False;
    missingHeaderSpecs: list[str] = [];
    emptySectionSpecs: list[any] = [];
    try {
        discovered = await discoverSpecFiles(specsDir);
        rootStat = await fs.stat(path.join(specsDir, "spec.md")).catch(
            lambda (e: any) -> any { JsNull }
        );
        hasRootLevelSpec = not missing(rootStat) and rootStat.isFile() == True;
        if hasRootLevelSpec {
            issues.append(
                issue(
                    "ERROR",
                    "spec.md",
                    "Delta spec found at specs/spec.md. Delta specs must live under a capability path (e.g. specs/<capability-path>/spec.md) — a file at the specs/ root is ignored when the change is applied or archived.",
                ),
            );
        }
        for spec in discovered {
            try {
                content = await fs.readFile(spec.specFile, "utf-8");
            } except Exception {
                continue;
            }
            plan = parseDeltaSpec(content);
            entryPath = FileSystemUtils.toPosixPath(path.relative(specsDir, spec.specFile));
            issues.extend(planNotes(plan, entryPath));
            sections = [title for (key, title) in SECTIONS if plan.sectionPresence[key]];
            entries = len(plan.added) + len(plan.modified) + len(plan.removed) + len(plan.renamed);
            totalDeltas += entries;
            if entries == 0 {
                if sections {
                    emptySectionSpecs.append(rec(path=entryPath, sections=sections));
                } else {
                    missingHeaderSpecs.append(entryPath);
                }
            }
            names: dict[str, list[str]] = {
                k: []
                for k in ["ADDED", "MODIFIED", "REMOVED", "FROM", "TO"]
            };
            def flag(message: str, level: str = "ERROR") {
                issues.append(issue(level, entryPath, message));
            }
            def once(kind: str, name: str, message: str) {
                key = normalizeRequirementName(name);
                if key in names[kind] {
                    flag(message);
                } else {
                    names[kind].append(key);
                }
            }
            for (op, blocks) in [("ADDED", plan.added), ("MODIFIED", plan.modified)] {
                for block in blocks {
                    label = f'{op} "{block.name}"';
                    once(op, block.name, f'Duplicate requirement in {op}: "{block.name}"');
                    text = requirementText(block.raw);
                    issues.extend(keywordIssues(text, label, block.name, entryPath, True));
                    if op == "ADDED" and text and len(text) > MAX_REQUIREMENT_TEXT_LENGTH {
                        flag(f"{label}: {M.REQUIREMENT_TOO_LONG}", "WARNING");
                    }
                    if countScenarios(block.raw.split("\n")[1:]) < 1 {
                        flag(
                            f"{label} must include at least one scenario{emptyScenarioHint(block.raw)}",
                        );
                    }
                    issues.extend(stepIssues(block.raw, label, entryPath));
                }
            }
            if mainSpecsDir and len(plan.modified) > 0 {
                mainSpecFile = path.join(mainSpecsDir, *spec.id.split("/"), "spec.md");
                issues.extend(
                    await mainSpecModifiedIssues(
                        plan.modified, plan.renamed, mainSpecFile, entryPath, mainSpecsDir
                    ),
                );
            }
            for name in plan.removed {
                once("REMOVED", name, f'Duplicate requirement in REMOVED: "{name}"');
            }
            for pair in plan.renamed {
                for side in ["FROM", "TO"] {
                    once(
                        side,
                        pair[side.lower()],
                        f'Duplicate {side} in RENAMED: "{pair[side.lower()]}"',
                    );
                }
            }
            (added, modified, removed) = (names["ADDED"], names["MODIFIED"], names["REMOVED"]);
            for (left, rights) in [("MODIFIED", ["REMOVED", "ADDED"]), ("ADDED", ["REMOVED"])] {
                for n in names[left] {
                    for right in rights {
                        if n in names[right] {
                            flag(f'Requirement present in both {left} and {right}: "{n}"');
                        }
                    }
                }
            }
            for pair in plan.renamed {
                fromKey = normalizeRequirementName(pair["from"]);
                if fromKey in modified {
                    flag(
                        f'MODIFIED references old name from RENAMED. Use new header for "{pair.to}"'
                    );
                }
                if normalizeRequirementName(pair.to) in added {
                    flag(f'RENAMED TO collides with ADDED for "{pair.to}"');
                }
                for r in removed {
                    if foldRequirementName(r) == foldRequirementName(fromKey) {
                        spelled = "" if r == fromKey else f' (REMOVED spells it "{r}")';
                        flag(
                            f'Requirement present in both RENAMED and REMOVED: "{pair["from"]}"{spelled}',
                        );
                        break;
                    }
                }
            }
        }
        if mainSpecsDir {
            reported: list[any] = [i.path for i in issues if i.level == "ERROR"];
            reported.extend(missingHeaderSpecs);
            reported.extend([s.path for s in emptySectionSpecs]);
            issues.extend(await archiveBlockers(changeDir, mainSpecsDir, reported));
        }
    } except Exception as e {
        if codeOf(e) not in ["ENOENT", "ENOTDIR"] {
            raise js_error(e);
        }
    }
    unreadDeltaFiles = await findUnreadDeltaFiles(specsDir);
    for file in unreadDeltaFiles {
        issues.append(
            issue(
                "ERROR",
                file.path,
                f"Delta spec found at specs/{file.path}. Delta specs must be a spec.md inside a capability folder — this file is ignored when the change is applied or archived. Move its requirements into specs/{file.expected}.",
            ),
        );
    }
    for spec in emptySectionSpecs {
        s = spec.sections;
        listed = ", ".join(s[:-1]) + " and " + s[-1] if len(s) > 1 else s[0];
        issues.append(
            issue(
                "ERROR",
                spec.path,
                f'Delta sections {listed} were found, but no requirement entries parsed. Ensure each section includes at least one "### Requirement:" block (REMOVED may use bullet list syntax).',
            ),
        );
    }
    for p in missingHeaderSpecs {
        issues.append(
            issue(
                "ERROR",
                p,
                'No delta sections found. Add headers such as "## ADDED Requirements" or move non-delta notes outside specs/.',
            ),
        );
    }
    marker = readSkipSpecsMarker(changeDir);
    issues.extend(markerIssues(marker));
    unknownKeys = readUnknownChangeMetadataKeys(changeDir);
    if len(unknownKeys) > 0 {
        issues.append(
            issue("WARNING", METADATA_FILENAME, formatUnknownChangeMetadataKeysMessage(unknownKeys))
        );
    }
    skipSpecs = marker.declared;
    specsDirHasFiles = False;
    if skipSpecs {
        try {
            specsDirHasFiles = await hasAnyFileUnder(specsDir);
        } except Exception {
            specsDirHasFiles = True;
        }
        if specsDirHasFiles {
            issues.append(issue("ERROR", "file", M.CHANGE_SKIP_SPECS_CONFLICT));
        }
    }
    if totalDeltas == 0 and not hasRootLevelSpec and len(unreadDeltaFiles) == 0 {
        if skipSpecs and not specsDirHasFiles {
            issues.append(issue("INFO", "file", M.CHANGE_SKIP_SPECS_ACCEPTED));
        } elif not skipSpecs {
            issues.append(issue("ERROR", "file", enrich(M.CHANGE_NO_DELTAS)));
        }
    }
    if at(options, "projectRoot") {
        issues.extend(await taskFileIssues(changeDir, options.projectRoot));
    }
    return issues;
}

obj Validator(globalThis.Object) {
    def init(strictMode: any = False) {
        super.init();
        self.strictMode = strictMode;
    }

    def createReport(issues: list[any]) -> any {
        count = lambda (level: str) -> int { len([i for i in issues if i.level == level]) };
        errors = count("ERROR");
        warnings = count("WARNING");
        return rec(
            valid=errors == 0 and (not self.strictMode or warnings == 0),
            issues=issues,
            summary=rec(errors=errors, warnings=warnings, info=count("INFO")),
        );
    }

    async def validateSpec(filePath: str) -> any {
        return self.createReport(specIssues(nameFromPath(filePath), None, filePath));
    }

    async def validateSpecContent(specName: str, content: str) -> any {
        return self.createReport(specIssues(specName, content));
    }

    async def validateChange(filePath: str) -> any {
        issues: list[any] = [];
        try {
            changeDir = path.dirname(filePath);
            change = await ChangeParser(
                readFileSync(filePath, "utf-8"), changeDir
            ).parseChangeWithDeltas(nameFromPath(filePath));
            result = ChangeSchema.safeParse(change);
            marker = readSkipSpecsMarker(changeDir);
            issues.extend(markerIssues(marker));
            if not result.success {
                issues.extend([
                    i
                    for i in zodIssues(result.error)
                    if not (marker.declared and i.message.startswith(M.CHANGE_NO_DELTAS))
                ]);
            }
            issues.extend(changeRules(change));
        } except Exception as e {
            issues.append(topLevelIssue(e));
        }
        return self.createReport(issues);
    }

    async def validateChangeDeltaSpecs(changeDir: str, options: any = None) -> any {
        return self.createReport(await deltaSpecIssues(changeDir, options));
    }

    def isValid(result: any) -> any {
        return result.valid;
    }
}

with entry {
    new(
        globalThis.Function,
        "C",
        "for (const k of ['validateSpec', 'validateSpecContent', 'validateChange', 'validateChangeDeltaSpecs']) { const f = C.prototype[k]; C.prototype[k] = function (...a) { return f.apply(this, a).then(); }; }",
    )(Validator);
}
