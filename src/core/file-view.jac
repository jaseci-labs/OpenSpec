import from "node:fs" { existsSync, readFileSync, statSync, readdirSync, lstatSync, readlinkSync }
import from "node:path" { default as path }

type FileView = any;

def:priv isDirectory(filePath: str) -> bool {
    try {
        return statSync(filePath).isDirectory();
    } except Exception {
        return False;
    }
}

def:priv linkTarget(filePath: str) -> any {
    try {
        if lstatSync(filePath).isSymbolicLink() {
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
