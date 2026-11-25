import from "node:fs" { promises as fs, readFileSync }
import from "node:path" { default as path }

def:priv sortBy(items: any, cmp: any) -> any {
    return globalThis.Array.prototype.sort.call(items, cmp);
}

def:priv rootOf(options: any) -> any {
    return at(options, "root") if truthy(at(options, "root")) else None;
}

def:priv show(payload: any) {
    globalThis.console.log(globalThis.JSON.stringify(payload, JsNull, 2));
}

async def:priv readChangeDirectoryEntries(changesDir: str) -> any {
    try {
        return await fs.readdir(changesDir, rec(withFileTypes=True));
    } except Exception as e {
        if at(js_error(e), "code") == "ENOENT" {
            return [];
        }
        raise js_error(e);
    }
}

async def:priv getLastModified(dirPath: str, archived: bool) -> any {
    latest: any = None;
    async def walk(dir: str) {
        for ent in await fs.readdir(dir, rec(withFileTypes=True)) {
            fullPath = path.join(dir, ent.name);
            try {
                if ent.isDirectory() {
                    await walk(fullPath);
                } else {
                    stat = await (
                        fs.lstat(fullPath)
                            if archived and ent.isSymbolicLink()
                            else fs.stat(fullPath)
                    );
                    if latest is None or stat.mtime.getTime() > latest.getTime() {
                        latest = stat.mtime;
                    }
                }
            } except Exception as e {
                if at(js_error(e), "code") not in ["ENOENT", "ELOOP"] {
                    raise js_error(e);
                }
            }
        }
    }
    await walk(dirPath);
    return latest ?? (await fs.stat(dirPath)).mtime;
}

def:priv formatRelativeTime(date: any) -> str {
    secs = (globalThis.Date.now() - date.getTime()) // 1000;
    (mins, hours) = (secs // 60, secs // 3600);
    days = hours // 24;
    if days > 30 {
        return date.toLocaleDateString();
    }
    for (n, unit) in [(days, "d"), (hours, "h"), (mins, "m")] {
        if n > 0 {
            return f"{n}{unit} ago";
        }
    }
    return "just now";
}

def:priv statusOf(c: any) -> any {
    return "not a change"
        if c.nested
        else formatTaskStatus(rec(total=c.totalTasks, completed=c.completedTasks));
}

def:priv printRows(heading: str, rows: list[tuple[any, str]]) {
    globalThis.console.log(heading);
    width = max([name.length for (name, _) in rows]);
    for (name, rest) in rows {
        globalThis.console.log(f"  {name.padEnd(width)}     {rest}");
    }
}

async def:priv listChanges(targetPath: str, options: any) {
    (archived, everything) = (truthy(at(options, "archived")), truthy(at(options, "all")));
    json = truthy(at(options, "json"));
    changesDir = path.join(targetPath, "openspec", "changes");
    archiveDir = path.join(changesDir, "archive");
    includeArchived = archived or everything;
    entries = await readChangeDirectoryEntries(changesDir);
    active = [e.name for e in entries if e.isDirectory() and e.name != "archive"]
        if not archived or everything
        else [];
    archivedNames = [
        e.name
        for e in (await readChangeDirectoryEntries(archiveDir) if includeArchived else [])
        if e.isDirectory() and not e.name.startswith(".")
    ];
    dirs = [(n, changesDir, False) for n in active] + [
        (n, archiveDir, True)
        for n in archivedNames
    ];
    if not dirs {
        if json {
            show(rec(changes=[], root=rootOf(options)));
        } else {
            globalThis.console.log(
                "No changes found."
                    if everything
                    else "No archived changes found." if archived else "No active changes found.",
            );
        }
        return;
    }
    findings = await findNestedChanges(changesDir, active);
    nestedBy = {f.name: f.nested for f in findings};
    changes: list[any] = [];
    for (name, parent, isArchived) in dirs {
        progress = await getTaskProgressForChange(parent, name, targetPath);
        changes.append(
            rec(
                name=name,
                completedTasks=progress.completed,
                totalTasks=progress.total,
                lastModified=await getLastModified(path.join(parent, name), isArchived),
                archived=isArchived,
                nested=None if isArchived else nestedBy.get(name),
            ),
        );
    }
    changes = sortBy(
        changes,
        (lambda (a: any, b: any) -> any { b.lastModified.getTime() - a.lastModified.getTime() })
            if (at(options, "sort") ?? "recent") == "recent"
            else (lambda (a: any, b: any) -> any { a.name.localeCompare(b.name) }),
    );
    if json {
        warnings = [
            rec(
                code="nested_change_directory",
                name=f.name,
                nested=f.nested,
                message=describeNestedChange(f),
            )
            for f in findings
        ];
        show(
            rec(
                changes=[
                    rec(
                        name=c.name,
                        completedTasks=c.completedTasks,
                        totalTasks=c.totalTasks,
                        lastModified=c.lastModified.toISOString(),
                        status="no-tasks"
                            if c.totalTasks == 0
                            else "complete" if c.completedTasks == c.totalTasks else "in-progress",
                        archived=c.archived if includeArchived else None,
                        nested=c.nested,
                    )
                    for c in changes
                ],
                warnings=warnings or None,
                root=rootOf(options),
            ),
        );
        return;
    }
    groups = [
        (heading, [c for c in changes if c.archived == flag])
        for (heading, flag) in [("Changes:", False), ("Archived Changes:", True)]
    ];
    for (index, group) in enumerate([g for g in groups if g[1]]) {
        if index > 0 {
            globalThis.console.log("");
        }
        printRows(
            group[0],
            [
                (c.name, f"{statusOf(c).padEnd(12)}  {formatRelativeTime(c.lastModified)}")
                for c in group[1]
            ],
        );
    }
    for f in findings {
        globalThis.console.log("");
        globalThis.console.log(f"Warning: {describeNestedChange(f)}");
    }
}

async def:priv listSpecs(targetPath: str, options: any) {
    if truthy(at(options, "archived")) or truthy(at(options, "all")) {
        raise new(globalThis.Error, "--archived and --all can only be used when listing changes.");
    }
    json = truthy(at(options, "json"));
    specsDir: any = path.join(targetPath, "openspec", "specs");
    discovered: list[any] = [];
    try {
        await fs.access(specsDir);
    } except Exception {
        specsDir = None;
    }
    if specsDir {
        discovered = await discoverSpecFiles(specsDir);
    }
    specs: list[any] = [];
    for d in discovered {
        count = 0;
        try {
            count = len(
                MarkdownParser(readFileSync(d.specFile, "utf-8")).parseSpec(d.id).requirements
            );
        } except Exception {}
        specs.append(rec(id=d.id, requirementCount=count));
    }
    specs = sortBy(specs, lambda (a: any, b: any) -> any { a.id.localeCompare(b.id) });
    if json {
        show(rec(specs=specs, root=rootOf(options)));
    } elif not specs {
        globalThis.console.log("No specs found.");
    } else {
        printRows("Specs:", [(s.id, f"requirements {s.requirementCount}") for s in specs]);
    }
}

obj ListCommand(globalThis.Object) {
    def execute(targetPath: str = ".", mode: str = "changes", options: any = None) -> any {
        return promise(
            listChanges(targetPath, options)
                if mode == "changes"
                else listSpecs(targetPath, options),
        );
    }
}
