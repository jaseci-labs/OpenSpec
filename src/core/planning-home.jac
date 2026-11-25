import from "node:fs" { default as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

type PlanningHome = any;

def:priv getSearchStartDirectory(startPath: str) -> str {
    resolved = path.resolve(startPath);
    try {
        return FileSystemUtils.canonicalizeExistingPath(
            resolved if fs.statSync(resolved).isDirectory() else path.dirname(resolved)
        );
    } except Exception {
        return resolved;
    }
}

def:priv hasOpenSpecDirectory(dirPath: str) -> bool {
    try {
        return fs.statSync(path.join(dirPath, "openspec")).isDirectory();
    } except Exception {
        return False;
    }
}

def findRepoPlanningRootSync(startPath: any = None) -> any {
    current = getSearchStartDirectory(startPath ?? process.cwd());
    while not hasOpenSpecDirectory(current) {
        parent = path.dirname(current);
        if parent == current {
            return JsNull;
        }
        current = parent;
    }
    return FileSystemUtils.canonicalizeExistingPath(current);
}

def:priv repoPlanningHome(repoRoot: str) -> any {
    return rec(
        kind="repo",
        root=repoRoot,
        changesDir=path.join(repoRoot, "openspec", "changes"),
        defaultSchema="spec-driven",
    );
}

def resolveCurrentPlanningHomeSync(options: any = None) -> any {
    searchStart = getSearchStartDirectory(at(options, "startPath") ?? process.cwd());
    repoRoot = findRepoPlanningRootSync(searchStart);
    if repoRoot {
        return repoPlanningHome(repoRoot);
    }
    if at(options, "allowImplicitRepoRoot") is False {
        raise new(globalThis.Error, "No OpenSpec planning home found from the current directory.");
    }
    return repoPlanningHome(FileSystemUtils.canonicalizeExistingPath(searchStart));
}

def getChangeDir(planningHome: any, changeName: str) -> str {
    return FileSystemUtils.joinPath(planningHome.changesDir, changeName);
}

def formatChangeLocation(planningHome: any, changeName: str) -> str {
    return path.relative(planningHome.root, getChangeDir(planningHome, changeName));
}
