import from "node:fs" { default as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

glob:priv INDICATORS: dict[str, tuple[str, str]] = {
    "done": ("green", "[x]"),
    "skipped": ("gray", "[~]"),
    "ready": ("yellow", "[ ]"),
    "blocked": ("red", "[-]"),
};

def statusFromError(error: any) -> any {
    if isRootSelectionError(error) {
        return merge(error.diagnostic);
    }
    return rec(severity="error", code="change_error", message=asErrorMessage(error));
}

def isColorDisabled -> bool {
    return process.env["NO_COLOR"] in ["1", "true"];
}

def getStatusColor(status: str) -> any {
    if isColorDisabled() {
        return lambda (text: str) -> str { text };
    }
    style = INDICATORS[status][0];
    return lambda (text: str) -> str { globalThis.Reflect.get(pick("chalk"), style)(text) };
}

def getStatusIndicator(status: str) -> str {
    return getStatusColor(status)(INDICATORS[status][1]);
}

async def getAvailableChanges(projectRoot: str, changesDir: any = None) -> list[any] {
    try {
        entries = await fs.promises.readdir(
            changesDir ?? path.join(projectRoot, "openspec", "changes"), rec(withFileTypes=True)
        );
    } except Exception as e {
        err = js_error(e);
        if at(err, "code") == "ENOENT" {
            return [];
        }
        raise err;
    }
    return [
        e.name
        for e in entries
        if e.isDirectory() and e.name != "archive" and not e.name.startswith(".")
    ];
}

def:priv lookupError(name: str) -> any {
    if name in [".", ".."] {
        return "Change name cannot be a relative path segment";
    }
    if "/" in name or "\\" in name {
        return "Change name cannot contain path separators";
    }
    if "\x00" in name {
        return "Change name cannot contain null characters";
    }
    if name.startswith(".") {
        return "Change name cannot start with a dot";
    }
    return "'archive' is reserved for archived changes" if name == "archive" else None;
}

async def validateChangeExists(
    changeName: any, projectRoot: str, changesDir: any = None, hints: any = None
) -> str {
    dir = changesDir ?? path.join(projectRoot, "openspec", "changes");
    hint = at(hints, "newChangeHint") ?? "openspec new change <name>";
    async def unavailable(lead: str, empty: str) -> any {
        available = await getAvailableChanges(projectRoot, dir);
        return new(
            globalThis.Error,
            f"{lead} Available changes:\n  " + "\n  ".join(available) if available else empty,
        );
    }
    if not changeName {
        raise await unavailable(
            "Missing required option --change.", f"No changes found. Create one with: {hint}"
        );
    }
    problem = lookupError(changeName);
    if problem {
        raise new(globalThis.Error, f"Invalid change name '{changeName}': {problem}");
    }
    changePath = path.join(dir, changeName);
    if not (fs.existsSync(changePath) and fs.statSync(changePath).isDirectory()) {
        raise await unavailable(
            f"Change '{changeName}' not found.",
            f"Change '{changeName}' not found. No changes exist. Create one with: {hint}",
        );
    }
    nested = await findNestedChangesIn(dir, changeName);
    if truthy(nested) {
        raise new(globalThis.Error, describeNestedChange(nested));
    }
    return changeName;
}

def validateSchemaExists(schemaName: str, projectRoot: any = None) -> str {
    if not getSchemaDir(schemaName, projectRoot) {
        raise new(
            globalThis.Error,
            f"Schema '{schemaName}' not found. Available schemas:\n  "
                + "\n  ".join(listSchemas(projectRoot)),
        );
    }
    return schemaName;
}
