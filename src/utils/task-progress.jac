import from "node:fs" { promises as fs }
import from "node:path" { default as path }

type ParsedTask = any;
type SchemaGlobCache = any;

glob:priv TASK_LINE_PATTERN: str = "^\\s*(?:[-*+]|\\d{1,9}[.)])\\s*\\[(?:\\s*([^\\]\\s]?)\\s*\\](?![([])|\\s+\\])\\s*(.*)",
          TASK_TEXT_BREAK_PATTERN: any = rx(
              "|".join([
                  "^\\s*$",
                  "^\\s*#{1,6}(?:\\s|$)",
                  "^\\s*(?:```|~~~)",
                  "^\\s*>",
                  "^\\s*<[!?]",
                  "^\\s*(?:=+|-+)\\s*$",
                  "^\\s*([-*_])(?:\\s*\\1){2,}\\s*$",
                  "^\\s*(?:[-*+]|\\d{1,9}[.)])(?:\\s|$)",
              ]),
          ),
          HARD_BREAK_PATTERN: any = rx("(?<!\\\\)(?:\\\\\\\\)*\\\\$");

def parseTaskLines(content: str) -> list[any] {
    return [rec(done=t.done, description=t.description) for t in parseLocatedTaskLines(content)];
}

def parseLocatedTaskLines(content: str) -> list[any] {
    tasks: list[any] = [];
    current: any = None;
    for (index, line) in enumerate(content.split("\n")) {
        text: any = line;
        m = matchOf(line, TASK_LINE_PATTERN);
        if not missing(m) {
            marker: any = m[1] ?? "";
            done = marker.toLowerCase() == "x";
            description: any = m[2];
            current = rec(done=done, description=description.trim(), line=index + 1);
            tasks.append(current);
        } elif current is not None and not TASK_TEXT_BREAK_PATTERN.test(line) {
            head: any = current.description;
            if HARD_BREAK_PATTERN.test(head) {
                head = head.slice(0, -1).trimEnd();
            }
            current.description = f"{head} {text.trim()}" if head else text.trim();
        } else {
            current = None;
        }
    }
    return tasks;
}

def countTasksFromContent(content: str) -> any {
    tasks = parseTaskLines(content);
    return rec(total=len(tasks), completed=len([t for t in tasks if t.done]));
}

def:priv resolveTrackedTasksGlob(changeDir: str, projectRoot: str, cache: any) -> any {
    try {
        schemaName = resolveSchemaForChange(changeDir, None, projectRoot);
        if truthy(cache) and cache.has(schemaName) {
            return cache.get(schemaName);
        }
        schema = resolveSchema(schemaName, projectRoot);
        tracks = at(schema, "apply", "tracks");
        generates: any = None;
        for a in schema.artifacts {
            if (a.generates == tracks if not missing(tracks) else a.id == "tasks") {
                generates = a.generates;
                break;
            }
        }
        if truthy(cache) {
            cache.set(schemaName, generates);
        }
        return generates;
    } except Exception {
        return None;
    }
}

def resolveTaskFilesForChange(
    changeDir: str, projectRoot: str, schemaGlobCache: any = None
) -> list[str] {
    generates = resolveTrackedTasksGlob(changeDir, projectRoot, schemaGlobCache);
    return resolveArtifactOutputs(changeDir, generates) if generates else [];
}

async def getTaskProgressDetailForChange(
    changesDir: str, changeName: str, projectRoot: str, schemaGlobCache: any = None
) -> any {
    changeDir = path.join(changesDir, changeName);
    files = resolveTaskFilesForChange(changeDir, projectRoot, schemaGlobCache);
    unreadable: list[str] = [];
    total = 0;
    completed = 0;
    for file in files or [path.join(changeDir, "tasks.md")] {
        try {
            progress = countTasksFromContent(await fs.readFile(file, "utf-8"));
            total += progress.total;
            completed += progress.completed;
        } except Exception as e {
            if at(js_error(e), "code") != "ENOENT" {
                unreadable.append(file);
            }
        }
    }
    return rec(total=total, completed=completed, unreadable=unreadable);
}

async def getTaskProgressForChange(changesDir: str, changeName: str, projectRoot: str) -> any {
    detail = await getTaskProgressDetailForChange(changesDir, changeName, projectRoot);
    return rec(total=detail.total, completed=detail.completed);
}

def formatTaskStatus(progress: any) -> str {
    if progress.total == 0 {
        return "No tasks";
    }
    if progress.completed == progress.total {
        return "✓ Complete";
    }
    return f"{progress.completed}/{progress.total} tasks";
}
