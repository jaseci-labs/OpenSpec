import from "node:fs" { existsSync, readFileSync, statSync, readdirSync, lstatSync, readlinkSync }
import from "node:path" { default as path }

type FileView = any;

def:priv isDirectory(filePath: str) -> bool {
    try {
        stats = statSync(filePath, rec(throwIfNoEntry=False));
        return stats is not None and stats.isDirectory();
    } except Exception {
        return False;
    }
}

def:priv linkTarget(filePath: str) -> any {
    try {
        stats = lstatSync(filePath, rec(throwIfNoEntry=False));
        if stats is not None and stats.isSymbolicLink() {
            return path.resolve(path.dirname(filePath), readlinkSync(filePath));
        }
    } except Exception {}
    return None;
}

glob DISK_VIEW: any = rec(
    exists=lambda (filePath: str) -> bool { existsSync(filePath) },
    read=lambda (filePath: str) -> str { readFileSync(filePath, "utf-8") },
    isDirectory=isDirectory,
    listDirectory=lambda (dirPath: str) -> any { readdirSync(dirPath) },
    linkTarget=linkTarget,
);
