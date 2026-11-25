import from "path" { default as path }
import from "fs" { default as fs }
import from "node:process" { default as process }

glob KNOWN_PROJECTS_FILE_NAME: str = "projects.json";

def knownProjectsPath -> str {
    return path.join(getGlobalDataDir(), KNOWN_PROJECTS_FILE_NAME);
}

def:priv projectState(projectPath: str) -> str {
    try {
        return "project"
            if fs.statSync(path.join(projectPath, OPENSPEC_DIR_NAME)).isDirectory()
            else "gone";
    } except Exception as e {
        return "gone" if at(js_error(e), "code") in ["ENOENT", "ENOTDIR"] else "unknown";
    }
}

def:priv recordedPaths -> any {
    try {
        handle = fs.openSync(knownProjectsPath(), "r");
        text: any = None;
        try {
            if fs.fstatSync(handle).size > 1024 * 1024 {
                return [];
            }
            text = fs.readFileSync(handle, "utf8");
        } finally {
            fs.closeSync(handle);
        }
        projects = at(globalThis.JSON.parse(text), "projects");
        if not globalThis.Array.isArray(projects) {
            return [];
        }
        return globalThis.Array.from(
            new(
                globalThis.Set,
                [
                    p
                    for p in projects
                    if kind(p) == "string"
                        and path.isAbsolute(p)
                        and not found(p, "[\\u0000-\\u001f\\u007f-\\u009f]")
                ],
            ),
        );
    } except Exception {
        return [];
    }
}

def readKnownProjects -> any {
    return [p for p in recordedPaths() if projectState(p) == "project"];
}

def rememberProject(projectPath: str) {
    draft: any = None;
    try {
        project: any = None;
        try {
            project = fs.realpathSync.native(projectPath);
        } except Exception {
            project = path.resolve(projectPath);
        }
        if projectState(project) != "project" {
            return;
        }
        recorded = recordedPaths();
        if project in recorded {
            return;
        }
        file = knownProjectsPath();
        fs.mkdirSync(path.dirname(file), rec(recursive=True));
        projects = globalThis.Array.prototype.sort.call(
            [p for p in recorded if projectState(p) != "gone"] + [project]
        );
        draft = f"{file}.{process.pid}.tmp";
        fs.writeFileSync(draft, globalThis.JSON.stringify(rec(projects=projects), None, 2) + "\n");
        fs.renameSync(draft, file);
    } except Exception {
        try {
            if draft {
                fs.rmSync(draft, rec(force=True));
            }
        } except Exception {}
    }
}
