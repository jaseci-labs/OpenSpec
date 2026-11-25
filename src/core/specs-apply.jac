import from "fs" { promises as fs }
import from "node:crypto" { randomUUID }
import from "node:process" { default as process }
import from "path" { default as path }

type SpecUpdate = any;

glob:priv OPENS_HTML_BLOCK: str = "^<(?:(?:script|pre|style|textarea)(?:[ \\t>]|$)|!--|\\?|![a-z]|!\\[CDATA\\[|\\/?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:[ \\t>]|\\/>|$))",
          HTML_TAG_ALONE: str = "^(?:<[A-Za-z][A-Za-z0-9-]*(?:\\s+[A-Za-z_:][\\w.:-]*(?:\\s*=\\s*(?:[^\\s\"'=<>`]+|'[^']*'|\"[^\"]*\"))?)*\\s*\\/?>|<\\/[A-Za-z][A-Za-z0-9-]*\\s*>)\\s*$",
          LIST_ITEM: str = "^(\\s*(?:[-*+]|\\d{1,9}[.)])\\s+)";

def:priv lf(s: any) -> str {
    return sub(s, "\\r\\n?", "\n");
}

def:priv fail(message: str) {
    raise new(globalThis.Error, message);
}

def:priv hdr(name: any) -> str {
    return f'"### Requirement: {name}"';
}

def:priv isLexicallyWithin(allowedDirectory: str, targetPath: str) -> bool {
    relative: str = path.relative(path.resolve(allowedDirectory), path.resolve(targetPath));
    return relative == ""
        or (
            relative != ".."
            and not relative.startswith(f"..{path.sep}")
            and not path.isAbsolute(relative)
        );
}

def:priv canonical(p: str) -> str {
    return FileSystemUtils.canonicalizeExistingPath(p);
}

def:priv resolveTrustedSpecPath(specsRoot: str, specPath: str, projectRoot: any = None) -> any {
    if not isLexicallyWithin(specsRoot, specPath) {
        fail(f"Path is outside the allowed directory: {specPath}");
    }
    try {
        assertSpecFileWithin(specsRoot, specPath);
        base = canonical(specsRoot);
        return rec(
            root=base,
            file=path.join(base, path.relative(path.resolve(specsRoot), path.resolve(specPath))),
        );
    } except Exception {
        base = canonical(path.dirname(specPath));
        if projectRoot and not isLexicallyWithin(canonical(projectRoot), base) {
            process.emitWarning(
                f"Capability '{path.basename(path.dirname(specPath))}' links outside the project; writing to {base}",
                "OpenSpecExternalSpecWrite",
            );
        }
        file = path.join(base, path.basename(specPath));
        assertSpecFileWithin(base, file);
        return rec(root=base, file=file);
    }
}

def:priv assertTrustedSpecPath(base: str, specPath: str) {
    if canonical(base) != path.resolve(base) {
        fail(f"Path is outside the allowed directory: {specPath}");
    }
    assertSpecFileWithin(base, specPath);
}

async def findSpecUpdates(changeDir: str, mainSpecsDir: str) -> list[any] {
    updates: list[any] = [];
    changeSpecsDir = path.join(changeDir, "specs");
    for spec in await discoverSpecFiles(changeSpecsDir) {
        source = resolveTrustedSpecPath(changeSpecsDir, spec.specFile);
        target = resolveTrustedSpecPath(
            mainSpecsDir,
            path.join(mainSpecsDir, spec.id, "spec.md"),
            path.dirname(path.dirname(mainSpecsDir)),
        );
        exists = True;
        try {
            await fs.access(target.file);
        } except Exception {
            exists = False;
        }
        updates.append(
            rec(
                id=spec.id,
                sourceRoot=source.root,
                source=source.file,
                targetRoot=target.root,
                target=target.file,
                exists=exists,
            ),
        );
    }
    return updates;
}

def:priv nearKey(blocks: dict[str, any], name: str, exclude: any = None) -> any {
    for key in blocks.keys() {
        if key != exclude and foldRequirementName(key) == foldRequirementName(name) {
            return key;
        }
    }
    return None;
}

def:priv uniqueNames(names: list[any], section: str, specName: str) -> list[str] {
    seen: list[str] = [];
    for name in names {
        key = normalizeRequirementName(name);
        if key in seen {
            fail(
                f"{specName} validation failed - duplicate requirement in {section} for header {hdr(name)}",
            );
        }
        seen.append(key);
    }
    return seen;
}

def:priv checkPlan(plan: any, specName: str, warn: any) {
    if len(plan.unpairedRenames) > 0 {
        first = plan.unpairedRenames[0];
        fail(
            f"{specName} validation failed - RENAMED entry on line {first.line} has no matching {'TO' if first.side == 'FROM' else 'FROM'}: "
                + f"for header {hdr(first.name)}. "
                + "Write each rename as a FROM: line followed immediately by its TO: line.",
        );
    }
    for o in plan.orphanedRequirements {
        if isUnrecognizedDeltaSection(o.section) {
            fail(
                f'{specName} validation failed - requirement "{o.name}" (line {o.line}) is under '
                    + f'"## {o.section}", which is not a delta section, so it would not be applied. '
                    + "Move it under ADDED/MODIFIED/REMOVED/RENAMED Requirements.",
            );
        }
    }
    for o in plan.orphanedRequirements {
        where = f'under "## {o.section}"' if o.section else 'above the first "## " section';
        warn(
            f'{specName} - requirement "{o.name}" (line {o.line}) is {where}, '
                + "which is not a delta section, so it was not applied. "
                + "Move it under ADDED/MODIFIED/REMOVED/RENAMED Requirements.",
        );
    }
    if plan.hasFrontmatter {
        warn(
            f"{specName} - frontmatter (line 1) is not carried into the main spec. It stays with the change.",
        );
    }
    for lost in plan.unappliedContent {
        warn(
            f"{specName} - {describeUnappliedContent(lost)} (line {lost.line}) is not carried into the main spec.",
        );
    }
    added = uniqueNames([a.name for a in plan.added], "ADDED", specName);
    modified = uniqueNames([m.name for m in plan.modified], "MODIFIED", specName);
    removed = uniqueNames(plan.removed, "REMOVED", specName);
    froms: list[str] = [];
    tos: list[str] = [];
    for r in plan.renamed {
        (fromKey, toKey) = (normalizeRequirementName(r["from"]), normalizeRequirementName(r.to));
        if fromKey in froms {
            fail(
                f"{specName} validation failed - duplicate FROM in RENAMED for header {hdr(r['from'])}",
            );
        }
        if toKey in tos {
            fail(f"{specName} validation failed - duplicate TO in RENAMED for header {hdr(r.to)}");
        }
        froms.append(fromKey);
        tos.append(toKey);
    }
    conflicts: list[tuple[str, str, str]] = [];
    for n in modified {
        if n in removed {
            conflicts.append((n, "MODIFIED", "REMOVED"));
        }
        if n in added {
            conflicts.append((n, "MODIFIED", "ADDED"));
        }
    }
    conflicts.extend([(n, "ADDED", "REMOVED") for n in added if n in removed]);
    for r in plan.renamed {
        (fromKey, toKey) = (normalizeRequirementName(r["from"]), normalizeRequirementName(r.to));
        for gone in removed {
            if foldRequirementName(gone) == foldRequirementName(fromKey) {
                fail(
                    f"{specName} validation failed - requirement present in multiple sections (RENAMED and REMOVED) for header {hdr(r['from'])}"
                        + ("" if gone == fromKey else f' (REMOVED spells it "{gone}")'),
                );
            }
        }
        if fromKey in modified {
            fail(
                f"{specName} validation failed - when a rename exists, MODIFIED must reference the NEW header {hdr(r.to)}",
            );
        }
        if toKey in added {
            fail(
                f"{specName} validation failed - RENAMED TO header collides with ADDED for {hdr(r.to)}",
            );
        }
    }
    if conflicts {
        (name, a, b) = conflicts[0];
        fail(
            f"{specName} validation failed - requirement present in multiple sections ({a} and {b}) for header {hdr(name)}",
        );
    }
    if len(plan.added) + len(plan.modified) + len(plan.removed) + len(plan.renamed) == 0 {
        fail(
            f"Delta parsing found no operations for {specName}. "
                + "Provide ADDED/MODIFIED/REMOVED/RENAMED sections in change spec.",
        );
    }
}

async def buildUpdatedSpec(update: any, changeName: str, options: any = None) -> any {
    warnings: list[str] = [];
    def warn(message: str) {
        warnings.append(message);
        if not at(options, "silent") {
            globalThis.console.log(pick("chalk").yellow(f"⚠️  Warning: {message}"));
        }
    }
    assertTrustedSpecPath(update.sourceRoot, update.source);
    changeContent = await fs.readFile(update.source, "utf-8");
    plan = parseDeltaSpec(changeContent);
    specName: str = update.id;
    checkPlan(plan, specName, warn);
    deltaPurpose = extractPurposeSection(changeContent);
    isNewSpec = False;
    assertTrustedSpecPath(update.targetRoot, update.target);
    targetContent: str = "";
    try {
        targetContent = await fs.readFile(update.target, "utf-8");
    } except Exception as e {
        err = js_error(e);
        if at(err, "code") not in ["ENOENT", "ENOTDIR"] {
            raise err;
        }
        isNewSpec = True;
    }
    if not isNewSpec {
        existingPurpose = extractPurposeSection(targetContent) if deltaPurpose else None;
        if existingPurpose and existingPurpose != deltaPurpose {
            warn(
                f"{specName} - delta Purpose ignored; {specName} already has one. "
                    + f"Edit {update.target} directly to change it.",
            );
        }
    } else {
        if len(plan.modified) > 0 or len(plan.renamed) > 0 {
            fail(
                f"{specName}: target spec does not exist; only ADDED requirements are allowed for new specs. MODIFIED and RENAMED operations require an existing spec.",
            );
        }
        if len(plan.removed) > 0 {
            warn(
                f"{specName} - {len(plan.removed)} REMOVED requirement(s) ignored for new spec (nothing to remove).",
            );
        }
        targetContent = buildSpecSkeleton(specName, changeName, deltaPurpose);
        overview = readableOverview(targetContent, specName) if deltaPurpose else None;
        if deltaPurpose and not overview {
            targetContent = buildSpecSkeleton(specName, changeName);
            warn(
                f"{specName} - delta Purpose ignored (it would leave the new spec unreadable); wrote the placeholder Purpose instead.",
            );
        } elif overview and len(overview) < MIN_PURPOSE_LENGTH {
            warn(
                f"{specName} - carried Purpose is under {MIN_PURPOSE_LENGTH} characters; "
                    + "openspec validate --strict reports it as too brief.",
            );
        }
    }
    issues = findMainSpecStructureIssues(targetContent);
    if len(issues) > 0 {
        details = "\n".join([f"line {i.line}: {i.message}" for i in issues]);
        fail(
            f"{specName}: target spec is structurally invalid and cannot be updated until fixed:\n{details}",
        );
    }
    parts = extractRequirementsSection(targetContent);
    blocks: dict[str, any] = {};
    for block in parts.bodyBlocks {
        blocks[normalizeRequirementName(block.name)] = block;
    }
    orderedKeys = [normalizeRequirementName(block.name) for block in parts.bodyBlocks];
    renamed = 0;
    for r in plan.renamed {
        (fromKey, toKey) = (normalizeRequirementName(r["from"]), normalizeRequirementName(r.to));
        if fromKey not in blocks {
            if toKey in blocks {
                near = nearKey(blocks, fromKey, toKey);
                if near is not None {
                    fail(
                        f"{specName} RENAMED failed for header {hdr(r['from'])} - source not found, but {hdr(blocks[near].name)} exists; fix the header to match it exactly",
                    );
                }
                continue;
            }
            fail(f"{specName} RENAMED failed for header {hdr(r['from'])} - source not found");
        }
        if toKey in blocks {
            fail(f"{specName} RENAMED failed for header {hdr(r.to)} - target already exists");
        }
        near = nearKey(blocks, toKey, fromKey);
        if near is not None {
            fail(
                f"{specName} RENAMED failed for header {hdr(r.to)} - {hdr(blocks[near].name)} already exists and differs only in case or spacing; choose a distinct name",
            );
        }
        rawLines = blocks[fromKey].raw.split("\n");
        rawLines[0] = f"### Requirement: {toKey}";
        del blocks[fromKey];
        blocks[toKey] = rec(headerLine=rawLines[0], name=toKey, raw="\n".join(rawLines));
        if fromKey in orderedKeys {
            orderedKeys[orderedKeys.index(fromKey)] = toKey;
        }
        renamed += 1;
    }
    removed = 0;
    for name in plan.removed {
        key = normalizeRequirementName(name);
        if key in blocks {
            del blocks[key];
            removed += 1;
        } elif not isNewSpec {
            near = nearKey(blocks, key);
            if near is not None {
                fail(
                    f"{specName} REMOVED failed for header {hdr(name)} - not found, but {hdr(blocks[near].name)} exists; fix the header to match it exactly",
                );
            }
            warn(
                f'{specName} - REMOVED requirement "{name}" is not in the current spec; treating it as already removed.',
            );
        }
    }
    modified = 0;
    for mod in plan.modified {
        key = normalizeRequirementName(mod.name);
        current = blocks.get(key);
        if current is None {
            fail(f"{specName} MODIFIED failed for header {hdr(mod.name)} - not found");
        }
        head = matchOf(mod.raw.split("\n")[0], "^###\\s*Requirement:\\s*(.+)\\s*$", "i");
        if not head or normalizeRequirementName(head[1]) != key {
            fail(
                f"{specName} MODIFIED failed for header {hdr(mod.name)} - header mismatch in content",
            );
        }
        diff = diffScenarioNames(current, mod);
        if len(diff.missing) > 0 {
            names = ", ".join([f'"{n}"' for n in diff.missing]);
            fail(
                f"{specName} MODIFIED failed for header {hdr(mod.name)} - current spec contains scenario(s) not present in the modified block: {names}. {describeScenarioBalance(diff)} Refresh the change spec before archiving to avoid dropping scenarios.",
            );
        }
        if normalizeBlockRaw(current.raw) != normalizeBlockRaw(mod.raw) {
            modified += 1;
        }
        blocks[key] = mod;
    }
    added = 0;
    for add in plan.added {
        key = normalizeRequirementName(add.name);
        existing = blocks.get(key);
        if existing is not None {
            if normalizeBlockRaw(existing.raw) == normalizeBlockRaw(add.raw) {
                continue;
            }
            fail(f"{specName} ADDED failed for header {hdr(add.name)} - already exists");
        }
        near = nearKey(blocks, key);
        if near is not None {
            fail(
                f"{specName} ADDED failed for header {hdr(add.name)} - {hdr(blocks[near].name)} already exists and differs only in case or spacing; use MODIFIED with that exact header to change it, or choose a distinct name",
            );
        }
        blocks[key] = add;
        added += 1;
    }
    kept: list[any] = [];
    seen: list[str] = [];
    for index in range(len(parts.bodyBlocks)) {
        block = parts.bodyBlocks[index];
        key = orderedKeys[index];
        replacement = blocks.get(key);
        if replacement is not None {
            kept.append(replacement);
            seen.append(key);
        }
        if replacement is not block {
            foreign = firstForeignTail(block.raw);
            if foreign is not None {
                tail = normalizeBlockRaw(foreign.raw);
                if replacement is None
                    or normalizeBlockRaw(replacement.raw).count(tail)
                        < normalizeBlockRaw(block.raw).count(tail)
                {
                    warn(
                        f'{specName} - "{foreign.heading}" sits inside requirement "{block.name}" and goes with it. '
                            + "Move it under its own requirement, or above `## Requirements`, to keep it.",
                    );
                }
            }
        }
    }
    kept.extend([block for (key, block) in blocks.items() if key not in seen]);
    preamble: any = parts.preamble;
    body: list[str] = [rtrim(preamble)] if preamble and trim(preamble) else [];
    body.extend([block.raw for block in kept]);
    sections = [
        s
        for s in [
            rtrim(parts.before),
            parts.headerLine,
            rtrim("\n\n".join(body)),
            trim(parts.after),
        ]
        if s != ""
    ];
    return rec(
        rebuilt=rtrim(collapseBlankRunsOutsideFences("\n\n".join(sections))) + "\n",
        counts=rec(added=added, modified=modified, removed=removed, renamed=renamed),
        warnings=warnings,
        noRequirementBlocks=len(kept) == 0,
        unaccountedContent=contentTheMergeCannotName(parts),
    );
}

def:priv firstForeignTail(raw: any) -> any {
    lines = lf(raw).split("\n");
    mask = buildCodeFenceMask(lines);
    for i in range(1, len(lines)) {
        if not mask[i] and found(lines[i], "^ {0,3}#{1,3}(?:[ \\t]|$)") {
            return rec(heading=trim(lines[i]), raw=rtrim("\n".join(lines[i:])));
        }
    }
    return None;
}

def:priv contentColumn(prefix: str) -> int {
    column = 0;
    for char in prefix {
        column += 4 - column % 4 if char == "\t" else 1;
    }
    return column;
}

def:priv mayBeRawHtml(line: str) -> bool {
    text = trim(line);
    return found(text, OPENS_HTML_BLOCK, "i") or found(text, HTML_TAG_ALONE);
}

def:priv interruptsParagraph(line: str) -> bool {
    return found(line, "^ {0,3}(?:>|(?:[-*_][ \\t]*){3,}$|(?:[-*+]|\\d{1,9}[.)])(?:[ \\t]|$)|\\|)")
        or (found(line, "^ {0,3}<") and mayBeRawHtml(line));
}

def:priv dropIndent(line: str, columns: int) -> str {
    column = 0;
    index = 0;
    while index < len(line) and column < columns {
        if line[index] == " " {
            column += 1;
        } elif line[index] == "\t" {
            column += 4 - column % 4;
        } else {
            break;
        }
        index += 1;
    }
    return line[index:];
}

def:priv isHeadingLine(line: str) -> bool {
    return found(line, "^ {0,3}#{1,6}(?:[ \\t]|$)") or found(line, "^\\s*<h[1-6]\\b", "i");
}

def:priv beforeLeftovers(before: any, out: list[str]) {
    lines = lf(sub(before, "^\\uFEFF", "", "")).split("\n");
    mask = buildCodeFenceMask(lines);
    inPurpose = False;
    titleSeen = False;
    previous = "";
    for i in range(len(lines)) {
        line = lines[i];
        if not trim(line) {
            previous = "";
            continue;
        }
        if not mask[i] {
            section = matchOf(line, "^ {0,3}##\\s+(.+?)\\s*$");
            if section {
                inPurpose = found(trim(section[1]), "^purpose$", "i");
                if not inPurpose {
                    out.append(trim(line));
                }
                previous = line;
                continue;
            }
            setext = inPurpose and trim(previous) != "" and found(line, "^ {0,3}(=+|-+)\\s*$");
            if setext or found(line, "^ {0,3}<h[1-6]\\b", "i") {
                out.append(trim(previous if setext else line));
                inPurpose = False;
                previous = line;
                continue;
            }
            if found(line, "^ {0,3}#\\s+.+$") {
                if not titleSeen and not inPurpose {
                    titleSeen = True;
                } else {
                    out.append(trim(line));
                    inPurpose = False;
                }
                previous = line;
                continue;
            }
        }
        previous = line;
        if not inPurpose {
            out.append(trim(line));
        }
    }
}

def:priv blockLeftovers(raw: any, out: list[str]) {
    lines = lf(raw).split("\n");
    mask = buildCodeFenceMask(lines);
    seenScenario = False;
    inBullets = False;
    bulletsSeen = False;
    listIndent: any = None;
    paragraphOpen = False;
    for i in range(len(lines)) {
        line = lines[i];
        if not trim(line) {
            inBullets = inBullets and not bulletsSeen;
            listIndent = None;
            paragraphOpen = False;
            continue;
        }
        if i == 0 {
            continue;
        }
        inside = listIndent is not None
            and contentColumn(matchOf(line, "^[ \\t]*")[0]) >= listIndent;
        within = dropIndent(line, listIndent) if inside else line;
        lazy = paragraphOpen and inBullets and not interruptsParagraph(within);
        if mask[i] {
            listIndent = listIndent if inside else None;
            paragraphOpen = False;
            continue;
        }
        if i > 1 and found(within, "^ {0,3}(?:=+|-+)\\s*$") and trim(lines[i - 1]) {
            out.append(trim(lines[i - 1]));
            listIndent = None;
            paragraphOpen = False;
            continue;
        }
        if (inside or lazy) and not isHeadingLine(within) {
            paragraphOpen = not interruptsParagraph(within);
            continue;
        }
        bullet = matchOf(line, LIST_ITEM);
        listIndent = None if missing(bullet) else contentColumn(bullet[1]);
        paragraphOpen = not missing(bullet);
        if found(line, "^ {0,3}####\\s+Scenario:", "i") {
            seenScenario = True;
            inBullets = True;
            bulletsSeen = False;
        } elif paragraphOpen and inBullets {
            bulletsSeen = True;
        } elif paragraphOpen and not seenScenario {
            continue;
        } elif seenScenario or paragraphOpen or found(line, "^\\s*\\|") or mayBeRawHtml(line) {
            out.append(trim(line));
        }
    }
}

def:priv contentTheMergeCannotName(parts: any) -> list[str] {
    out: list[str] = [];
    beforeLeftovers(parts.before, out);
    for slice in [parts.preamble, parts.after] {
        out.extend([trim(line) for line in slice.split("\n") if trim(line)]);
    }
    for block in parts.bodyBlocks {
        foreign = firstForeignTail(block.raw);
        if foreign is not None {
            out.append(foreign.heading);
        }
        blockLeftovers(block.raw, out);
    }
    unique: list[str] = [];
    for line in out {
        if line not in unique {
            unique.append(line);
        }
    }
    return unique;
}

def:priv collapseBlankRunsOutsideFences(content: str) -> str {
    lines = content.split("\n");
    mask = buildCodeFenceMask(lines);
    kept: list[str] = [];
    blank = 0;
    for i in range(len(lines)) {
        line = lines[i];
        blank = blank + 1 if line == "" and not mask[i] else 0;
        if blank <= 1 {
            kept.append(line);
        }
    }
    return "\n".join(kept);
}

def:priv normalizeBlockRaw(raw: any) -> str {
    return trim(lf(raw));
}

def:priv errCode(error: any) -> any {
    return at(js_error(error), "code");
}

async def:priv assertGone(target: str, message: str) {
    try {
        await fs.lstat(target);
    } except Exception as e {
        if errCode(e) != "ENOENT" {
            raise js_error(e);
        }
        return;
    }
    fail(message);
}

async def retireSpec(update: any, mainSpecsDir: str, options: any = None) -> any {
    verify = at(options, "verifyDisplaced");
    deferDelete = at(options, "deferDelete");
    if deferDelete and verify is None {
        fail("Deferred retirement requires displaced-file verification.");
    }
    cannot = f"Could not retire capability '{update.id}':";
    realSource: any = None;
    try {
        if not (await fs.lstat(update.target)).isSymbolicLink() {
            realSource = await fs.realpath(update.target);
        }
    } except Exception as e {
        if errCode(e) == "ENOENT" {
            return rec(retired=False);
        }
        fail(f"{cannot} could not verify {update.target} before deletion ({messageOf(e)}).");
    }
    if realSource is not None {
        inside = False;
        try {
            inside = realSource.startsWith((await fs.realpath(mainSpecsDir)) + path.sep);
        } except Exception as e {
            fail(
                f"{cannot} could not verify that {update.target} is inside {mainSpecsDir} ({messageOf(e)}).",
            );
        }
        if not inside {
            fail(
                f"{cannot} {update.target} resolves outside {mainSpecsDir}. Remove the external file by hand, or replace the symlink and rerun.",
            );
        }
    }
    displacedPath: any = None;
    try {
        beforeMutate = at(options, "beforeMutate");
        if beforeMutate is not None {
            await globalThis.Promise.resolve(beforeMutate());
        }
        if verify {
            displaced = f"{update.target}.openspec-retire-{randomUUID()}";
            displacedPath = displaced;
            await fs.rename(update.target, displaced);
            try {
                await globalThis.Promise.resolve(verify(displaced));
                await assertGone(
                    update.target,
                    f"A concurrent file appeared at {update.target} while archive was retiring it.",
                );
                if not deferDelete {
                    await fs.unlink(displaced);
                }
            } except Exception as e {
                await assertGone(
                    update.target,
                    f"{messageOf(e)} A concurrent file now occupies {update.target}; the displaced spec was retained at {displaced}.",
                );
                await fs.rename(displaced, update.target);
                raise js_error(e);
            }
        } else {
            await fs.unlink(update.target);
        }
    } except Exception as e {
        if errCode(e) == "ENOENT" {
            return rec(retired=False);
        }
        fail(
            f"{cannot} failed to delete {update.target} ({globalThis.String(at(js_error(e), 'message'))}). Remove it by hand, then rerun the archive.",
        );
    }
    if not deferDelete {
        await pruneEmptyDirs(path.dirname(update.target), mainSpecsDir);
    }
    if not at(options, "silent") {
        nominal = at(options, "displayPath") ?? f"openspec/specs/{update.id}/spec.md";
        globalThis.console.log(f"Retiring {nominal}: all requirements removed.");
    }
    return merge(
        rec(retired=True),
        rec(resolvedPath=realSource) if realSource else None,
        rec(displacedPath=displacedPath) if deferDelete and displacedPath else None,
    );
}

async def finalizeRetiredSpec(target: str, displacedPath: str, mainSpecsDir: str) {
    await fs.unlink(displacedPath);
    await pruneEmptyDirs(path.dirname(target), mainSpecsDir);
}

async def pruneEmptyDirs(startDir: str, boundaryDir: str) {
    boundary: any = None;
    try {
        boundary = await fs.realpath(boundaryDir);
    } except Exception {
        return;
    }
    dir = startDir;
    while True {
        try {
            if (await fs.lstat(dir)).isSymbolicLink() {
                return;
            }
            realDir: any = await fs.realpath(dir);
            if realDir == boundary or not realDir.startsWith(boundary + path.sep) {
                return;
            }
            if len(await fs.readdir(dir)) > 0 {
                return;
            }
            await fs.rmdir(dir);
        } except Exception {
            return;
        }
        dir = path.dirname(dir);
    }
}

async def writeUpdatedSpec(update: any, rebuilt: str, counts: any, options: any = None) {
    assertTrustedSpecPath(update.targetRoot, update.target);
    verifiedTarget = canonical(update.target);
    await fs.mkdir(path.dirname(update.target), rec(recursive=True));
    toWrite = rebuilt;
    try {
        toWrite = matchLineEnding(rebuilt, await fs.readFile(verifiedTarget, "utf-8"));
    } except Exception as e {
        if errCode(e) != "ENOENT" {
            raise js_error(e);
        }
    }
    beforeMutate = at(options, "beforeMutate");
    if beforeMutate is not None {
        await globalThis.Promise.resolve(beforeMutate());
    }
    assertTrustedSpecPath(update.targetRoot, update.target);
    if canonical(update.target) != verifiedTarget {
        fail(f"Spec target for '{update.id}' changed before it could be written: {update.target}");
    }
    await fs.writeFile(verifiedTarget, toWrite);
    if at(options, "silent") {
        return;
    }
    nominal = at(options, "displayPath") ?? f"openspec/specs/{update.id}/spec.md";
    log = globalThis.console.log;
    log(f"Applying changes to {nominal}:");
    for (key, sign) in [("added", "+"), ("modified", "~"), ("removed", "-"), ("renamed", "→")] {
        if at(counts, key) {
            log(f"  {sign} {counts[key]} {key}");
        }
    }
}

def:priv extractPurposeSection(content: str) -> any {
    lines = lf(sub(content, "^\\uFEFF", "", "")).split("\n");
    for i in range(findFrontmatterEnd(lines)) {
        lines[i] = "";
    }
    masked = sub(
        "\n".join(lines),
        "<!--[\\s\\S]*?(?:--!?>|$)",
        lambda (m: str) -> str { sub(m, "[^\\n]", " ") },
    ).split("\n");
    fence = buildCodeFenceMask(masked);
    start = -1;
    end = len(masked);
    for i in range(len(masked)) {
        line = masked[i];
        if fence[i] {
            continue;
        }
        if start == -1 and found(line, "^##\\s+Purpose(?:[ \\t]+#+)?\\s*$", "i") {
            start = i;
        } elif start != -1 and found(line, "^##\\s+") {
            end = i;
            break;
        }
    }
    if start == -1
        or not trim("\n".join([masked[i] for i in range(start + 1, end) if not fence[i]]))
    {
        return None;
    }
    return trim("\n".join(lines[start + 1:end])) or None;
}

def:priv readableOverview(skeleton: str, specName: str) -> any {
    if "<!--" in skeleton or len(findMainSpecStructureIssues(skeleton)) > 0 {
        return None;
    }
    try {
        return trim(MarkdownParser(skeleton).parseSpec(specName).overview) or None;
    } except Exception {
        return None;
    }
}

def buildSpecSkeleton(specFolderName: str, changeName: str, purpose: any = None) -> str {
    body = (trim(purpose) if purpose else "")
        or f"{PURPOSE_PLACEHOLDER_PREFIX}{changeName}{PURPOSE_PLACEHOLDER_SUFFIX}";
    return f"# {specFolderName} Specification\n\n## Purpose\n\n{body}\n\n## Requirements\n";
}
