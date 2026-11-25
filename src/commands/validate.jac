import from "node:fs" { promises as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

glob:priv PREFIX: dict[str, str] = {"ERROR": "✗", "WARNING": "⚠"},
          REPORT_FIX: str = "Use --report full|findings with --all, --changes, --specs, or --archived, without an item name. Do not combine archived and active scopes.";

def:priv log(text: str) {
    globalThis.console.log(text);
}

def:priv logError(text: str) {
    globalThis.console.error(text);
}

def:priv printJson(value: any) {
    log(globalThis.JSON.stringify(value, JsNull, 2));
}

def:priv prefixOf(issue: any) -> str {
    return PREFIX.get(issue.level, "ℹ");
}

def:priv printProblem(json: any, code: str, message: str, fix: any = None) {
    if truthy(json) {
        printJson(rec(status=[rec(severity="error", code=code, message=message, fix=fix)]));
    } else {
        logError(message);
    }
    process.exitCode = 1;
}

def:priv failWithFix(json: any, code: str, message: str, fix: str) {
    if truthy(json) {
        printProblem(json, code, message, fix);
    } else {
        logError(f"Error: {message}");
        logError(f"Fix: {fix}");
        process.exitCode = 1;
    }
}

def:priv tally(results: list[any]) -> any {
    passed = len([r for r in results if r.valid]);
    return rec(items=len(results), passed=passed, failed=len(results) - passed);
}

def:priv summarize(results: list[any], kinds: list[str]) -> any {
    return rec(
        totals=tally(results),
        byType=globalThis.Object.fromEntries([
            [k, tally([r for r in results if r.type == k])]
            for k in kinds
        ]),
    );
}

def:priv normalizeConcurrency(value: any) -> any {
    if not value {
        return None;
    }
    n = globalThis.Number.parseInt(value, 10);
    return None if globalThis.Number.isNaN(n) or n <= 0 else n;
}

async def:priv startSpinner(opts: any, text: str) -> any {
    if not opts.json and isInteractive(opts) and canRenderSpinner() {
        return (await load("ora")).default(text).start();
    }
    return None;
}

def:priv stop(spinner: any) {
    if spinner is not None {
        spinner.stop();
    }
}

def projectValidationFindings(full: any, scope: str) -> any {
    itemFindings = [i for i in full.items if len(i.issues) > 0];
    return rec(
        report=rec(
            kind="validation-findings",
            version="1.0",
            scope=scope,
            returnedItems=len(itemFindings),
            totalItems=full.summary.totals.items,
        ),
        itemFindings=itemFindings,
        summary=full.summary,
        root=full.root,
    );
}

async def:priv listChangeIds(root_: any) -> list[str] {
    return sorted(await getAvailableChanges(root_.path, root_.changesDir));
}

async def:priv nestedChangeIssues(root_: any, id: str) -> any {
    nested = await findNestedChangesIn(root_.changesDir, id);
    return [rec(level="ERROR", path="file", message=describeNestedChange(nested))]
        if truthy(nested)
        else None;
}

async def:priv validateOne(validator: any, root_: any, kind_: str, id: str) -> any {
    start = globalThis.Date.now();
    result: any = None;
    if kind_ == "change" {
        issues = await nestedChangeIssues(root_, id);
        result = rec(valid=False, issues=issues)
            if issues is not None
            else await validator.validateChangeDeltaSpecs(
                path.join(root_.changesDir, id),
                rec(mainSpecsDir=root_.specsDir, projectRoot=root_.path),
            );
    } else {
        result = await validator.validateSpec(path.join(root_.specsDir, id, "spec.md"));
    }
    return rec(
        id=id,
        type=kind_,
        valid=result.valid,
        issues=result.issues,
        durationMs=globalThis.Date.now() - start,
    );
}

def:priv printNextSteps(kind_: str, id: str, root_: any, issues: any) {
    def mentions(text: str) -> bool {
        for i in issues {
            if text in i.message {
                return True;
            }
        }
        return False;
    }
    bullets: list[str] = [];
    if kind_ != "change" {
        bullets = [
            "- Ensure spec includes ## Purpose and ## Requirements sections",
            "- Each requirement MUST include at least one #### Scenario: block",
            "- Re-run with --json to see structured report",
        ];
    } elif mentions(NESTED_CHANGE_ISSUE_MARKER) {
        bullets = [
            "- Move each nested change directly under openspec/changes/, folding the namespace into its name",
            "- Only specs may be nested by domain; change directories are always flat",
        ];
    } elif mentions(VALIDATION_MESSAGES.CHANGE_SKIP_SPECS_CONFLICT) {
        bullets = [
            "- This change declares skip_specs (no spec deltas): delete the files under specs/, or remove skip_specs from .openspec.yaml if requirements do change",
            "- skip_specs is only honored when .openspec.yaml is valid change metadata (schema: <name> naming a known schema is required)",
        ];
    } elif mentions(VALIDATION_MESSAGES.CHANGE_SKIP_SPECS_INVALID_METADATA) {
        bullets = [
            "- Fix .openspec.yaml so the skip_specs marker can be honored (schema: <name> naming a known schema is required)",
            "- Or remove skip_specs from .openspec.yaml and add delta specs instead",
        ];
    } else {
        bullets = [
            "- Ensure change has deltas in specs/: use headers ## ADDED/MODIFIED/REMOVED/RENAMED Requirements",
            "- Each requirement MUST include at least one #### Scenario: block",
            f"- Debug parsed deltas: {withStoreFlag(root_, f'openspec show {id} --json --deltas-only')}",
        ];
    }
    logError("Next steps:");
    for b in bullets {
        logError(f"  {b}");
    }
}

def:priv nameProblemOf(kind_: str, id: str) -> any {
    if kind_ == "change" {
        return folderStyleNameProblem(id, "Change name");
    }
    for segment in id.split("/") {
        problem = folderStyleNameProblem(segment, "Spec id");
        if truthy(problem) {
            return problem;
        }
    }
    return JsNull;
}

async def:priv validateByType(root_: any, kind_: str, id: str, opts: any) {
    problem = nameProblemOf(kind_, id);
    if truthy(problem) {
        printProblem(opts.json, "invalid_item", problem);
        return;
    }
    item = await validateOne(Validator(opts.strict), root_, kind_, id);
    process.exitCode = 0 if item.valid else 1;
    if opts.json {
        printJson(
            rec(
                items=[item],
                summary=summarize([item], [kind_]),
                version="1.0",
                root=toRootOutput(root_),
            ),
        );
        return;
    }
    label = "Change" if kind_ == "change" else "Specification";
    if item.valid {
        log(f"{label} '{id}' is valid");
    } else {
        logError(f"{label} '{id}' has issues");
    }
    for i in item.issues {
        logError(f"{prefixOf(i)} [{i.level}] {i.path}: {i.message}");
    }
    if not item.valid {
        printNextSteps(kind_, id, root_, item.issues);
    }
}

async def:priv validateDirectItem(root_: any, itemName: str, typeOverride: any, opts: any) {
    changes = await listChangeIds(root_);
    specs = await getSpecIds(root_.path);
    (isChange, isSpec) = (itemName in changes, itemName in specs);
    resolved: any = typeOverride ?? ("change" if isChange else "spec" if isSpec else None);
    if resolved is None {
        suggestions = nearestMatches(itemName, changes + specs);
        printProblem(
            opts.json,
            "unknown_item",
            f"Unknown item '{itemName}'. Did you mean: {', '.join(suggestions)}?"
                if suggestions
                else f"Unknown item '{itemName}'.",
        );
        return;
    }
    if typeOverride is None and isChange and isSpec {
        message = f"Ambiguous item '{itemName}' matches both a change and a spec.";
        if opts.json {
            printProblem(True, "ambiguous_item", message, "Pass --type change|spec.");
            return;
        }
        logError(message);
        logError(
            "Pass --type change|spec."
                if isStoreSelectedRoot(root_)
                else "Pass --type change|spec, or use: openspec change validate / openspec spec validate",
        );
        process.exitCode = 1;
        return;
    }
    await validateByType(root_, resolved, itemName, opts);
}

def:priv printBulkDetails(results: list[any], root_: any) {
    for r in results {
        if not r.valid {
            storeFlag = f" --store {root_.storeId}" if isStoreSelectedRoot(root_) else "";
            log(f"Details: openspec validate {r.id} --type {r.type}{storeFlag}");
            return;
        }
    }
}

def:priv printTotals(totals: any) {
    log(f"Totals: {totals.passed} passed, {totals.failed} failed ({totals.items} items)");
}

def:priv printFindingsReport(full: any, scope: str, json: bool, root_: any) {
    findings = projectValidationFindings(full, scope);
    if json {
        printJson(findings);
        return;
    }
    log(f"Scope: {scope} ({findings.report.totalItems} items)");
    if not findings.itemFindings {
        log("No item findings.");
    }
    for item in findings.itemFindings {
        logError(f"{item.type}/{item.id}");
        for i in item.issues {
            logError(f"  [{i.level}] {i.path}: {i.message}");
        }
    }
    printTotals(findings.summary.totals);
    if scope != "archived" {
        printBulkDetails(full.items, root_);
    }
}

def:priv printFull(results: list[any], summary: any, root_: any, opts: any) -> bool {
    if opts["findingsScope"] {
        printFindingsReport(
            rec(items=results, summary=summary, root=toRootOutput(root_)),
            opts.findingsScope,
            opts.json,
            root_,
        );
        return True;
    }
    if opts.json {
        printJson(rec(items=results, summary=summary, version="1.0", root=toRootOutput(root_)));
        return True;
    }
    return False;
}

async def:priv runBulkValidation(root_: any, changes: bool, specs: bool, opts: any) {
    spinner = await startSpinner(opts, "Validating...");
    changeIds = await listChangeIds(root_) if changes else [];
    specIds = await getSpecIds(root_.path) if specs else [];
    queue: list[tuple[str, str]] = [("change", id) for id in changeIds] + [
        ("spec", id)
        for id in specIds
    ];
    kinds = [k for (k, on) in [("change", changes), ("spec", specs)] if on];
    if not queue {
        stop(spinner);
        if not printFull([], summarize([], kinds), root_, opts) {
            log("No items found to validate.");
        }
        process.exitCode = 0;
        return;
    }
    concurrency = normalizeConcurrency(opts["concurrency"])
        ?? normalizeConcurrency(process.env["OPENSPEC_CONCURRENCY"])
        ?? 6;
    validator = Validator(opts.strict);
    results: list[any] = [];
    index = 0;
    async def worker {
        while index < len(queue) {
            current = index;
            index += 1;
            if spinner is not None {
                spinner.text = f"Validating ({current + 1}/{len(queue)})...";
            }
            (kind_, id) = queue[current];
            try {
                results.append(await validateOne(validator, root_, kind_, id));
            } except Exception as e {
                results.append(
                    rec(
                        id=id,
                        type=kind_,
                        valid=False,
                        issues=[
                            rec(
                                level="ERROR",
                                path="file",
                                message=at(js_error(e), "message") or "Unknown error",
                            ),
                        ],
                        durationMs=0,
                    ),
                );
            }
        }
    }
    await globalThis.Promise.all([promise(worker()) for _ in range(min(concurrency, len(queue)))]);
    stop(spinner);
    results = globalThis.Array.prototype.sort.call(
        results, lambda (a: any, b: any) -> int { a.id.localeCompare(b.id) }
    );
    summary = summarize(results, kinds);
    if not printFull(results, summary, root_, opts) {
        for r in results {
            if r.valid {
                log(f"✓ {r.type}/{r.id}");
            } else {
                logError(f"✗ {r.type}/{r.id}");
            }
            for i in r.issues {
                logError(f"  {prefixOf(i)} [{i.level}] {i.path}: {i.message}");
            }
        }
        printTotals(summary.totals);
        printBulkDetails(results, root_);
    }
    process.exitCode = 1 if summary.totals.failed > 0 else 0;
}

async def:priv listArchivedChangeIds(root_: any) -> list[str] {
    try {
        entries = await fs.readdir(root_.archiveDir, rec(withFileTypes=True));
    } except Exception as e {
        if at(js_error(e), "code") == "ENOENT" {
            return [];
        }
        raise js_error(e);
    }
    return sorted([e.name for e in entries if e.isDirectory() and not e.name.startswith(".")]);
}

async def:priv archivedIssues(root_: any, id: str, cache: any) -> list[any] {
    issues: list[any] = [];
    try {
        progress = await getTaskProgressDetailForChange(root_.archiveDir, id, root_.path, cache);
        for file in progress.unreadable {
            issues.append(
                rec(
                    level="ERROR",
                    path=FileSystemUtils.toPosixPath(path.relative(root_.path, file)),
                    message="could not read task file",
                ),
            );
        }
        incomplete = max(progress.total - progress.completed, 0);
        if incomplete > 0 {
            issues.append(
                rec(
                    level="ERROR",
                    path="tasks.md",
                    message=f"{incomplete} incomplete task{'' if incomplete == 1 else 's'} ({progress.completed}/{progress.total} completed)",
                ),
            );
        }
    } except Exception as e {
        issues.append(
            rec(
                level="ERROR",
                path="tasks.md",
                message=at(js_error(e), "message") or "Unknown error",
            ),
        );
    }
    return issues;
}

async def:priv runArchivedTaskValidation(root_: any, opts: any) {
    ids = await listArchivedChangeIds(root_);
    spinner = await startSpinner(opts, "Validating archived changes...");
    cache = new(globalThis.Map);
    results: list[any] = [];
    for id in ids {
        start = globalThis.Date.now();
        issues = await archivedIssues(root_, id, cache);
        results.append(
            rec(
                id=id,
                type="change",
                valid=len(issues) == 0,
                issues=issues,
                durationMs=globalThis.Date.now() - start,
            ),
        );
    }
    stop(spinner);
    summary = summarize(results, ["change"]);
    failed = summary.totals.failed > 0;
    if printFull(results, summary, root_, opts) {
        process.exitCode = 1 if failed else 0;
        return;
    }
    if not results {
        log("No archived changes found.");
        process.exitCode = 0;
        return;
    }
    for r in results {
        if r.valid {
            log(f"✓ change/{r.id}");
        } else {
            logError(f"✗ change/{r.id}");
            for i in r.issues {
                logError(f"  {prefixOf(i)} {i.message}");
            }
        }
    }
    printTotals(summary.totals);
    process.exitCode = 1 if failed else 0;
}

async def:priv runInteractiveSelector(root_: any, opts: any) {
    select = (await load("@inquirer/prompts")).select;
    choice = await select(
        rec(
            message="What would you like to validate?",
            choices=[
                rec(name="All (changes + specs)", value="all"),
                rec(name="All changes", value="changes"),
                rec(name="All specs", value="specs"),
                rec(name="Pick a specific change or spec", value="one"),
            ],
        ),
    );
    if choice != "one" {
        await runBulkValidation(root_, choice != "specs", choice != "changes", opts);
        return;
    }
    changeIds = await listChangeIds(root_);
    specIds = await getSpecIds(root_.path);
    items = [rec(name=f"change/{id}", value=rec(type="change", id=id)) for id in changeIds] + [
        rec(name=f"spec/{id}", value=rec(type="spec", id=id))
        for id in specIds
    ];
    if not items {
        logError("No items found to validate.");
        process.exitCode = 1;
        return;
    }
    picked = await select(rec(message="Pick an item", choices=items));
    await validateByType(root_, picked.type, picked.id, opts);
}

def:priv printNonInteractiveHint(root_: any) {
    logError("Nothing to validate. Try one of:");
    for args in ["--all", "--changes", "--specs", "<item-name>"] {
        logError(f"  {withStoreFlag(root_, f'openspec validate {args}')}");
    }
    logError("Or run in an interactive terminal.");
}

def:priv reportRequestProblem(itemName: any, options: any, bulk: bool) -> any {
    wanted = options["report"];
    if wanted not in ["full", "findings"] {
        return f"Unknown validation report '{wanted}'.";
    }
    if itemName is not None {
        return "A validation report cannot be combined with an item name.";
    }
    if truthy(options["archived"]) and bulk {
        return "A validation report cannot combine archived and active scopes.";
    }
    if not truthy(options["archived"]) and not bulk {
        return "A validation report requires an explicit bulk scope.";
    }
    return None;
}

obj ValidateCommand(globalThis.Object) {
    async def execute(itemName: any = None, options: any = None) {
        options = options ?? rec();
        flag = lambda (key: str) -> bool { truthy(options[key]) };
        bulk = flag("all") or flag("changes") or flag("specs");
        findingsScope: any = None;
        if options["report"] is not None {
            problem = reportRequestProblem(itemName, options, bulk);
            if problem {
                failWithFix(
                    options["json"], "invalid_validation_report_request", problem, REPORT_FIX
                );
                return;
            }
            if options["report"] == "findings" {
                findingsScope = "archived"
                    if flag("archived")
                    else "all"
                        if flag("all") or (flag("changes") and flag("specs"))
                        else "changes" if flag("changes") else "specs";
            }
        }
        root_ = await resolveRootForCommand(
            options,
            merge(rec(json=options["json"]), rec(allowImplicitRoot=False) if bulk else None),
        );
        if not truthy(root_) {
            return;
        }
        configError = readConfigParseError(root_.path);
        if truthy(configError) {
            file = configError.filePath;
            unreadable = configError.kind == "read";
            failWithFix(
                options["json"],
                "unreadable_config" if unreadable else "unparseable_config",
                f"Could not {'read' if unreadable else 'parse'} {file} ({configError.message}).",
                f"Make {file} a readable file, or remove it."
                    if unreadable
                    else f"Fix the YAML syntax in {file}.",
            );
            return;
        }
        opts = rec(strict=flag("strict"), json=flag("json"), concurrency=options["concurrency"]);
        if flag("archived") {
            await runArchivedTaskValidation(
                root_,
                rec(
                    json=flag("json"),
                    noInteractive=resolveNoInteractive(options),
                    findingsScope=findingsScope,
                ),
            );
        } elif bulk {
            await runBulkValidation(
                root_,
                flag("all") or flag("changes"),
                flag("all") or flag("specs"),
                merge(
                    opts,
                    rec(noInteractive=resolveNoInteractive(options), findingsScope=findingsScope),
                ),
            );
        } elif not itemName {
            if isInteractive(options) {
                await runInteractiveSelector(root_, opts);
            } else {
                printNonInteractiveHint(root_);
                process.exitCode = 1;
            }
        } else {
            typeOverride: any = options["type"];
            typeOverride = typeOverride.toLowerCase() if typeOverride else None;
            await validateDirectItem(
                root_,
                itemName,
                typeOverride if typeOverride in ["change", "spec"] else None,
                rec(strict=flag("strict"), json=flag("json")),
            );
        }
    }
}

with entry {
    jsAsync(ValidateCommand, ["execute"]);
}
