import from "node:fs" { promises as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

glob:priv paintWith: any = new(
    globalThis.Function, "c", "s", "t", "return s.split('.').reduce((f, k) => f[k], c)(t)"
);

def:priv paint(style: str, text: str) -> str {
    return paintWith(pick("chalk"), style, text);
}

def:priv log(*parts: any) {
    globalThis.console.log(*parts);
}

def:priv logError(*parts: any) {
    globalThis.console.error(*parts);
}

async def:priv isDefinitelyMissing(target: str) -> bool {
    try {
        await fs.access(target);
        return False;
    } except Exception as e {
        return at(js_error(e), "code") == "ENOENT";
    }
}

async def:priv accessible(target: str) -> bool {
    try {
        await fs.access(target);
        return True;
    } except Exception {
        return False;
    }
}

async def:priv isDirectory(target: str) -> bool {
    try {
        return (await fs.stat(target)).isDirectory();
    } except Exception {
        return False;
    }
}

def:priv isChangeDirectoryName(changesPath: str, changeDir: str) -> bool {
    return path.dirname(path.resolve(changeDir)) == path.resolve(changesPath);
}

def:priv extractTitle(content: str, changeName: str) -> str {
    found = matchOf(content, "^#\\s+(?:Change:\\s+)?(.+)$", "im");
    title: any = found[1].trim() if truthy(found) else "";
    return title if title and title.toLowerCase() != "proposal" else changeName;
}

async def:priv pickChange(message: str, base: any, options: any) -> any {
    changes = await getActiveChangeIds(base);
    if isInteractive(options) and changes {
        return await (await load("@inquirer/prompts")).select(
            rec(message=message, choices=[rec(name=id, value=id) for id in changes])
        );
    }
    logError(
        f"No change specified. Available IDs: {', '.join(changes)}"
            if changes
            else "No change specified. No active changes found.",
    );
    logError("Hint: use \"openspec change list\" to view available changes.");
    process.exitCode = 1;
    return None;
}

async def:priv parseProposal(changeDir: str, proposalPath: str, changeName: str) -> any {
    FileSystemUtils.assertPathWithin(changeDir, proposalPath);
    content = await fs.readFile(proposalPath, "utf-8");
    change = await ChangeParser(content, changeDir).parseChangeWithDeltas(changeName);
    return rec(title=extractTitle(content, changeName), deltaCount=len(change.deltas));
}

def:priv printNextSteps(issues: any) {
    def mentions(text: str) -> bool {
        for i in issues {
            if text in i.message {
                return True;
            }
        }
        return False;
    }
    bullets = [
        "- This change declares skip_specs (no spec deltas): delete the files under specs/, or remove skip_specs from .openspec.yaml if requirements do change",
        "- skip_specs is only honored when .openspec.yaml is valid change metadata (schema: <name> is required)",
    ]
        if mentions(VALIDATION_MESSAGES.CHANGE_SKIP_SPECS_CONFLICT)
        else [
            "- Fix .openspec.yaml so the skip_specs marker can be honored (schema: <name> is required)",
            "- Or remove skip_specs from .openspec.yaml and add delta specs instead",
        ]
            if mentions(VALIDATION_MESSAGES.CHANGE_SKIP_SPECS_INVALID_METADATA)
            else [
                "- Ensure change has deltas in specs/: use headers ## ADDED/MODIFIED/REMOVED/RENAMED Requirements",
                "- Each requirement MUST include at least one #### Scenario: block",
                "- Debug parsed deltas: openspec change show <id> --json --deltas-only",
            ];
    logError("Next steps:");
    for b in bullets {
        logError(f"  {b}");
    }
}

def:priv printDiffText(results: list[any]) {
    currentCap = "";
    for r in results {
        if r.capability != currentCap {
            if currentCap {
                log();
            }
            currentCap = r.capability;
            log(paint("bold.underline", currentCap));
            log();
        }
        op = r.operation;
        if op in ["ADDED", "REMOVED"] {
            color = "green" if op == "ADDED" else "red";
            log(paint(f"{color}.bold", f"  {op}: {r.requirementName}"));
            for line in r.raw.split("\n") {
                log(paint(color, f"    {line}"));
            }
        } elif op == "RENAMED" {
            log(paint("cyan.bold", f"  RENAMED: {r.rename['from']} → {r.rename['to']}"));
        } else {
            log(paint("yellow.bold", f"  MODIFIED: {r.requirementName}"));
            if r["warning"] {
                log(paint("yellow", f"    ⚠ {r.warning}"));
            }
            if r["diff"] is None {
                for line in r.raw.split("\n") {
                    log(f"    {line}");
                }
            } elif r.diff == "" {
                log(paint("dim", "    (no textual changes)"));
            } else {
                for line in r.diff.split("\n") {
                    log(
                        paint("green", f"    {line}")
                            if line.startswith("+")
                            else paint("red", f"    {line}")
                                if line.startswith("-")
                                else f"    {line}",
                    );
                }
            }
        }
        log();
    }
}

obj ChangeCommand(globalThis.Object) {
    def init(rootPath: any = None) {
        super.init();
        self.converter = JsonConverter();
        self.rootPath = rootPath;
    }

    def getChangesPath -> str {
        return path.join(self.rootPath ?? process.cwd(), "openspec", "changes");
    }

    def getSpecsPath -> str {
        return path.join(self.rootPath ?? process.cwd(), "openspec", "specs");
    }

    async def show(changeName: any = None, options: any = None) {
        changesPath = self.getChangesPath();
        if not changeName {
            changeName = await pickChange(
                "Select a change to show", self.rootPath ?? process.cwd(), options
            );
            if changeName is None {
                return;
            }
        }
        changeDir = path.join(changesPath, changeName);
        proposalPath = path.join(changeDir, "proposal.md");
        notFound = f"Change \"{changeName}\" not found at {proposalPath}";
        if not isChangeDirectoryName(changesPath, changeDir) {
            raise new(globalThis.Error, notFound);
        }
        if not await accessible(proposalPath) {
            if not await isDirectory(changeDir) {
                raise new(globalThis.Error, notFound);
            }
            nested = await findNestedChangesIn(changesPath, changeName);
            if truthy(nested) {
                raise new(globalThis.Error, describeNestedChange(nested));
            }
            raise new(
                globalThis.Error,
                f"Change \"{changeName}\" has no proposal.md yet. Run \"openspec status --change {changeName}\" to see which artifact comes next.",
            );
        }
        FileSystemUtils.assertPathWithin(path.dirname(proposalPath), proposalPath);
        FileSystemUtils.assertPathWithin(changeDir, proposalPath);
        if not truthy(at(options, "json")) {
            log(await fs.readFile(proposalPath, "utf-8"));
            if truthy(at(options, "diff")) {
                await self.showSpecDiffs(changeName, changesPath);
            }
            return;
        }
        jsonOutput = await self.converter.convertChangeToJson(proposalPath);
        if truthy(options["requirementsOnly"]) {
            logError("Flag --requirements-only is deprecated; use --deltas-only instead.");
        }
        parsed = globalThis.JSON.parse(jsonOutput);
        FileSystemUtils.assertPathWithin(changeDir, proposalPath);
        title = extractTitle(await fs.readFile(proposalPath, "utf-8"), changeName);
        deltas: any = parsed["deltas"] or [];
        if truthy(options["diff"]) {
            await self.enrichDeltasWithDiffs(deltas, changeName, changesPath);
        }
        log(
            globalThis.JSON.stringify(
                merge(
                    rec(id=parsed["name"], title=title, deltaCount=len(deltas), deltas=deltas),
                    rec(root=options.rootOutput) if truthy(options["rootOutput"]) else None,
                ),
                JsNull,
                2,
            ),
        );
    }

    async def collectSpecDiffs(changeName: str, changesPath: str) -> any {
        mainSpecsDir = self.getSpecsPath();
        discovered = await discoverSpecFiles(path.join(changesPath, changeName, "specs"));
        results: list[any] = [];
        def push(capability: str, operation: str, name: str, raw: str, **extra: any) -> any {
            item = merge(
                rec(capability=capability, operation=operation, requirementName=name, raw=raw),
                rec(**extra),
            );
            results.append(item);
            return item;
        }
        for d in discovered {
            capability: str = d.id;
            deltaContent = await fs.readFile(d.specFile, "utf-8");
            mainSpecPath = path.join(mainSpecsDir, *capability.split("/"), "spec.md");
            mainContent: any = None;
            try {
                assertDiscoveredSpecFile(mainSpecsDir, mainSpecPath);
                mainContent = await fs.readFile(mainSpecPath, "utf-8");
            } except Exception as e {
                if at(js_error(e), "code") != "ENOENT" {
                    raise js_error(e);
                }
            }
            plan = parseDeltaSpec(deltaContent);
            renameMap = buildRenameMap(plan.renamed);
            for block in plan.added {
                push(capability, "ADDED", block.name, block.raw);
            }
            removedRaw = {foldRequirementName(b.name): b.raw for b in plan.removedBlocks};
            for name in plan.removed {
                push(
                    capability,
                    "REMOVED",
                    name,
                    removedRaw.get(foldRequirementName(name)) ?? f"### Requirement: {name}",
                );
            }
            for rename in plan.renamed {
                push(capability, "RENAMED", rename.to, "", rename=rename);
            }
            for block in plan.modified {
                item = push(capability, "MODIFIED", block.name, block.raw);
                lookupName = renameMap.get(foldRequirementName(block.name)) ?? block.name;
                hit: any = extractRequirementBlock(mainContent, lookupName)
                    if mainContent
                    else JsNull;
                if truthy(hit) {
                    item.diff = diffRequirementBlock(
                        hit.raw, block.raw, f"{capability}/{block.name}"
                    );
                    if not hit.exact {
                        item.warning = f"Header differs from the main spec's \"{hit.name}\" only in case or spacing; archive matches names exactly, so reconcile them before archiving";
                    }
                } elif mainContent {
                    item.warning = f"No matching main requirement found for \"{lookupName}\" in {capability}";
                } else {
                    item.warning = f"No main spec at openspec/specs/{capability}/spec.md, so MODIFIED requirement \"{block.name}\" has nothing to diff against";
                }
            }
        }
        return rec(capabilities=[d.id for d in discovered], results=results);
    }

    async def enrichDeltasWithDiffs(deltas: any, changeName: str, changesPath: str) {
        bySpec: dict[str, list[any]] = {};
        for d in deltas {
            if d["spec"] and d["operation"] == "MODIFIED" {
                bySpec[d.spec] = (bySpec.get(d.spec) ?? []) + [d];
            }
        }
        if not bySpec {
            return;
        }
        entriesBySpec: dict[str, list[any]] = {};
        for e in (await self.collectSpecDiffs(changeName, changesPath)).results {
            if e.operation == "MODIFIED" {
                entriesBySpec[e.capability] = (entriesBySpec.get(e.capability) ?? []) + [e];
            }
        }
        for (capability, modified) in bySpec.items() {
            for (delta, item) in zip(modified, entriesBySpec.get(capability) ?? []) {
                for key in ["diff", "warning"] {
                    if item[key] is not None {
                        delta[key] = item[key];
                    }
                }
            }
        }
    }

    async def showSpecDiffs(changeName: str, changesPath: str) {
        collected = await self.collectSpecDiffs(changeName, changesPath);
        log();
        if not collected.capabilities or not collected.results {
            log(f"No delta specs to diff for change \"{changeName}\".");
            return;
        }
        log(paint("bold", "Specifications Changed (diffs)"));
        log();
        printDiffText(collected.results);
    }

    async def listChanges(options: any = None) {
        changesPath = path.join(process.cwd(), "openspec", "changes");
        changes = await getActiveChangeIds();
        if truthy(at(options, "json")) {
            details: list[any] = [];
            for changeName in changes {
                changeDir = path.join(changesPath, changeName);
                proposalPath = path.join(changeDir, "proposal.md");
                taskStatus = await getTaskProgressForChange(changesPath, changeName, process.cwd());
                summary: any = rec(title=changeName, deltaCount=0);
                if not await isDefinitelyMissing(proposalPath) {
                    try {
                        summary = await parseProposal(changeDir, proposalPath, changeName);
                    } except Exception {
                        summary = rec(title="Unknown", deltaCount=0);
                    }
                }
                details.append(
                    rec(
                        id=changeName,
                        title=summary.title,
                        deltaCount=summary.deltaCount,
                        taskStatus=taskStatus,
                    ),
                );
            }
            log(
                globalThis.JSON.stringify(
                    globalThis.Array.prototype.sort.call(
                        details, lambda (a: any, b: any) -> int { a.id.localeCompare(b.id) }
                    ),
                    JsNull,
                    2,
                ),
            );
            return;
        }
        if not changes {
            log("No items found");
            return;
        }
        for changeName in sorted(changes) {
            if not truthy(at(options, "long")) {
                log(changeName);
                continue;
            }
            changeDir = path.join(changesPath, changeName);
            proposalPath = path.join(changeDir, "proposal.md");
            progress = await getTaskProgressForChange(changesPath, changeName, process.cwd());
            tasks = f" [tasks {progress.completed}/{progress.total}]" if progress.total > 0 else "";
            if await isDefinitelyMissing(proposalPath) {
                log(f"{changeName}: (no proposal.md yet){tasks}");
                continue;
            }
            try {
                summary = await parseProposal(changeDir, proposalPath, changeName);
                log(f"{changeName}: {summary.title} [deltas {summary.deltaCount}]{tasks}");
            } except Exception {
                log(f"{changeName}: (unable to read){tasks}");
            }
        }
    }

    async def validate(changeName: any = None, options: any = None) {
        changesPath = path.join(process.cwd(), "openspec", "changes");
        if not changeName {
            changeName = await pickChange("Select a change to validate", None, options);
            if changeName is None {
                return;
            }
        }
        changeDir = path.join(changesPath, changeName);
        if not isChangeDirectoryName(changesPath, changeDir) or not await accessible(changeDir) {
            raise new(globalThis.Error, f"Change \"{changeName}\" not found at {changeDir}");
        }
        result = await Validator(at(options, "strict") or False).validateChangeDeltaSpecs(
            changeDir,
            rec(
                mainSpecsDir=path.join(path.dirname(changesPath), "specs"),
                projectRoot=path.dirname(path.dirname(changesPath)),
            ),
        );
        if truthy(at(options, "json")) {
            log(globalThis.JSON.stringify(result, JsNull, 2));
            return;
        }
        if result.valid {
            log(f"Change \"{changeName}\" is valid");
        } else {
            logError(f"Change \"{changeName}\" has issues");
        }
        for i in result.issues {
            prefix = {"ERROR": "✗", "WARNING": "⚠"}.get(i.level, "ℹ");
            logError(f"{prefix} [{i.level}] {i.path}: {i.message}");
        }
        if not result.valid {
            printNextSteps(result.issues);
            process.exitCode = 1;
        }
    }
}

with entry {
    jsAsync(
        ChangeCommand,
        [
            "show",
            "collectSpecDiffs",
            "enrichDeltasWithDiffs",
            "showSpecDiffs",
            "listChanges",
            "validate",
        ],
    );
    new(globalThis.Function, "C", "C.prototype.list = C.prototype.listChanges")(ChangeCommand);
}
