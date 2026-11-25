import from "node:fs" { existsSync, readFileSync, readdirSync }
import from "node:path" { default as path }
import from "node:process" { default as process }

glob:priv chalk: any = pick("chalk"),
          RULE: str = "─" * 60,
          BORDER: str = "═" * 60;

def:priv paint(style: str, text: any) -> str {
    target: any = chalk;
    parts = style.split(".");
    for part in parts[:-1] {
        target = globalThis.Reflect.get(target, part);
    }
    return globalThis.Reflect.apply(globalThis.Reflect.get(target, parts[-1]), target, [text]);
}

def:priv log(text: str) {
    globalThis.console.log(text);
}

def:priv byName(a: any, b: any) -> any {
    return a.name.localeCompare(b.name);
}

def:priv sortBy(items: any, cmp: any) -> any {
    return globalThis.Array.prototype.sort.call(items, cmp);
}

def:priv ratio(p: any) -> any {
    return p.completed / p.total if p.total > 0 else 0;
}

def:priv percent(done: int, total: int) -> any {
    return globalThis.Math.round(done / total * 100);
}

def:priv sanitize(value: str) -> str {
    return sub(value, "[\\u0000-\\u001f\\u007f-\\u009f]", "?");
}

def:priv section(style: str, title: str, items: list[any], line: any) {
    if items {
        log(paint(style, f"\n{title}"));
        log(RULE);
        for item in items {
            for text in line(item) {
                log(text);
            }
        }
    }
}

def:priv artifactText(a: any) -> str {
    id = sanitize(a.id);
    if a.status == "done" {
        return f"{id}{chalk.green('✓')}";
    }
    if a.status == "ready" {
        return f"{id}{chalk.cyan('→')}";
    }
    return chalk.dim(f"{id} (skipped)" if a.status == "skipped" else id);
}

def:priv progressBar(completed: int, total: int, width: int = 20) -> str {
    if total == 0 {
        return chalk.dim("─" * width);
    }
    filled = globalThis.Math.round(completed / total * width);
    return f"[{chalk.green('█' * filled)}{chalk.dim('░' * (width - filled))}]";
}

async def:priv getChangesData(openspecDir: str) -> any {
    changesDir = path.join(openspecDir, "changes");
    projectRoot = path.dirname(openspecDir);
    draft: list[any] = [];
    active: list[any] = [];
    completed: list[any] = [];
    if not existsSync(changesDir) {
        return rec(draft=draft, active=active, completed=completed);
    }
    for ent in readdirSync(changesDir, rec(withFileTypes=True)) {
        if not ent.isDirectory() or ent.name == "archive" {
            continue;
        }
        name: str = ent.name;
        progress = await getTaskProgressForChange(changesDir, name, projectRoot);
        if progress.total == 0 {
            draft.append(rec(name=name));
        } elif progress.completed == progress.total {
            completed.append(rec(name=name));
        } else {
            workflowStatus: any = None;
            try {
                workflowStatus = formatChangeStatus(loadChangeContext(projectRoot, name));
            } except Exception as e {
                err = js_error(e);
                reason = err.message
                    if globalThis.Error.prototype.isPrototypeOf(err)
                    else globalThis.String(err);
                globalThis.console.warn(
                    chalk.yellow(
                        sanitize(f"Could not load workflow status for \"{name}\": {reason}")
                    ),
                );
            }
            active.append(rec(name=name, progress=progress, workflowStatus=workflowStatus));
        }
    }
    return rec(
        draft=sortBy(draft, byName),
        active=sortBy(
            active,
            lambda (a: any, b: any) -> any {
                (ratio(a.progress) - ratio(b.progress)) or byName(a, b)
            },
        ),
        completed=sortBy(completed, byName),
    );
}

async def:priv getSpecsData(openspecDir: str) -> list[any] {
    specsDir = path.join(openspecDir, "specs");
    specs: list[any] = [];
    if not existsSync(specsDir) {
        return specs;
    }
    for d in await discoverSpecFiles(specsDir) {
        count = 0;
        try {
            count = len(
                MarkdownParser(readFileSync(d.specFile, "utf-8")).parseSpec(d.id).requirements
            );
        } except Exception {}
        specs.append(rec(name=d.id, requirementCount=count));
    }
    return specs;
}

def:priv displaySummary(changes: any, specs: list[any]) {
    totalTasks = sum([c.progress.total for c in changes.active]);
    completedTasks = sum([c.progress.completed for c in changes.active]);
    log(chalk.bold("Summary:"));
    log(
        f"  {chalk.cyan('●')} Specifications: {chalk.bold(len(specs))} specs, {chalk.bold(sum([s.requirementCount for s in specs]))} requirements",
    );
    if changes.draft {
        log(f"  {chalk.gray('●')} Draft Changes: {chalk.bold(len(changes.draft))}");
    }
    log(f"  {chalk.yellow('●')} Active Changes: {chalk.bold(len(changes.active))} in progress");
    log(f"  {chalk.green('●')} Completed Changes: {chalk.bold(len(changes.completed))}");
    if totalTasks > 0 {
        log(
            f"  {chalk.magenta('●')} Task Progress: {chalk.bold(f'{completedTasks}/{totalTasks}')} ({percent(completedTasks, totalTasks)}% complete)",
        );
    }
}

def:priv activeLines(change: any, width: int) -> list[str] {
    p = change.progress;
    pct = percent(p.completed, p.total) if p.total > 0 else 0;
    name: any = change.name;
    lines = [
        f"  {chalk.yellow('◉')} {chalk.bold(name.padEnd(width))} {progressBar(p.completed, p.total)} {chalk.dim(f'{pct}%')}",
    ];
    status = change.workflowStatus;
    if status {
        lines.append(
            f"    {chalk.dim(f'└─ [{sanitize(status.schemaName)}]')} {' '.join([artifactText(a) for a in status.artifacts])}",
        );
    }
    return lines;
}

async def:priv viewDashboard(targetPath: str) {
    openspecDir = path.join(targetPath, "openspec");
    if not existsSync(openspecDir) {
        globalThis.console.error(chalk.red("No openspec directory found"));
        process.exit(1);
    }
    log(chalk.bold("\nOpenSpec Dashboard\n"));
    log(BORDER);
    changes = await getChangesData(openspecDir);
    specs = await getSpecsData(openspecDir);
    displaySummary(changes, specs);
    section(
        "bold.gray",
        "Draft Changes",
        changes.draft,
        lambda (c: any) -> list[str] { [f"  {chalk.gray('○')} {c.name}"] },
    );
    width = min(48, globalThis.Math.max(30, *[c.name.length for c in changes.active]));
    section(
        "bold.cyan",
        "Active Changes",
        changes.active,
        lambda (c: any) -> list[str] { activeLines(c, width) },
    );
    section(
        "bold.green",
        "Completed Changes",
        changes.completed,
        lambda (c: any) -> list[str] { [f"  {chalk.green('✓')} {c.name}"] },
    );
    section(
        "bold.blue",
        "Specifications",
        sortBy(specs, lambda (a: any, b: any) -> any { b.requirementCount - a.requirementCount }),
        lambda (s: any) -> list[str] {
            [
                f"  {chalk.blue('▪')} {chalk.bold(s.name.padEnd(30))} {chalk.dim(f'{s.requirementCount} requirement' + ('' if s.requirementCount == 1 else 's'))}",
            ]
        },
    );
    log("\n" + BORDER);
    log(
        chalk.dim(
            f"\nUse {chalk.white('openspec list --changes')} or {chalk.white('openspec list --specs')} for detailed views",
        ),
    );
}

obj ViewCommand(globalThis.Object) {
    def execute(targetPath: str = ".") -> any {
        return promise(viewDashboard(targetPath));
    }
}
