import from "node:fs" { promises as fs }
import from "node:path" { default as path }

glob:priv CHANGE_ROOT_MARKERS: list[str] = [
              METADATA_FILENAME,
              "proposal.md",
              "tasks.md",
              "design.md",
          ],
          MAX_NESTING_DEPTH: int = 3;

type NestedChangeFinding = any;

glob NESTED_CHANGE_ISSUE_MARKER: str = "is not a change: it is a folder wrapping";

async def:priv entriesOf(dir: str) -> any {
    try {
        return await fs.readdir(dir, rec(withFileTypes=True));
    } except Exception {
        return [];
    }
}

async def:priv looksLikeChange(dir: str, projectRoot: str) -> bool {
    for marker in CHANGE_ROOT_MARKERS {
        try {
            if (await fs.stat(path.join(dir, marker))).isFile() {
                return True;
            }
        } except Exception {}
    }
    try {
        if await hasAnyFileUnder(path.join(dir, "specs")) {
            return True;
        }
    } except Exception {}
    try {
        schema = resolveSchema(resolveSchemaForChange(dir, None, projectRoot), projectRoot);
        for a in schema.artifacts {
            if artifactOutputExists(dir, a.generates) {
                return True;
            }
        }
    } except Exception {}
    return False;
}

async def:priv collectNested(
    dir: str, prefix: str, depth: int, found: list[str], projectRoot: str
) {
    if depth > MAX_NESTING_DEPTH {
        return;
    }
    for ent in await entriesOf(dir) {
        if not ent.isDirectory() or ent.name.startswith(".") {
            continue;
        }
        childPath = path.join(dir, ent.name);
        id = f"{prefix}/{ent.name}";
        if await looksLikeChange(childPath, projectRoot) {
            found.append(id);
        } else {
            await collectNested(childPath, id, depth + 1, found, projectRoot);
        }
    }
}

async def findNestedChangesIn(changesDir: str, name: str) -> any {
    if name == "archive" or name.startswith(".") {
        return None;
    }
    dir = path.join(changesDir, name);
    projectRoot = path.resolve(changesDir, "..", "..");
    if await looksLikeChange(dir, projectRoot) {
        return None;
    }
    for ent in await entriesOf(dir) {
        if not ent.name.startswith(".") and not ent.isDirectory() {
            return None;
        }
    }
    nested: list[str] = [];
    await collectNested(dir, name, 1, nested, projectRoot);
    if not nested {
        return None;
    }
    return rec(name=name, nested=globalThis.Array.prototype.sort.call(nested));
}

async def findNestedChanges(changesDir: str, names: list[str]) -> list[any] {
    findings = await globalThis.Promise.all([
        promise(findNestedChangesIn(changesDir, name))
        for name in names
    ]);
    return [f for f in findings if f is not None];
}

def describeNestedChange(finding: any) -> str {
    listed = ", ".join([f"openspec/changes/{id}/" for id in finding.nested]);
    example = "-".join(finding.nested[0].split("/"));
    return f"\"{finding.name}\" {NESTED_CHANGE_ISSUE_MARKER} {listed}. A change must be a directory directly under openspec/changes/, so those nested directories are invisible to OpenSpec while the folder around them is reported as a change. Nested paths are supported under openspec/specs/ only. Rename each nested change to a flat name (for example \"{example}\").";
}
