import from "node:fs" { default as fs }
import from "node:path" { default as path }
import from "node:process" { default as process }

def findCopiesOnPath(pathValue: any = None, platform: any = None) -> list[str] {
    win = (platform ?? process.platform) == "win32";
    seen: set[str] = set();
    copies: list[str] = [];
    for folder in (pathValue ?? process.env["PATH"] ?? "").split(path.delimiter) {
        if not folder {
            continue;
        }
        for name in (["openspec.exe", "openspec.cmd"] if win else ["openspec"]) {
            candidate: any = path.join(folder, name);
            try {
                if not fs.statSync(candidate).isFile() {
                    continue;
                }
                if not win {
                    fs.accessSync(candidate, fs.constants.X_OK);
                }
                key = candidate.toLowerCase() if win else candidate;
                if key not in seen {
                    seen.add(key);
                    copies.append(candidate);
                }
            } except Exception {}
        }
    }
    return copies;
}

def:priv real(value: str) -> any {
    try {
        return fs.realpathSync(value);
    } except Exception {
        return path.resolve(value);
    }
}

def samePath(a: str, b: str) -> bool {
    (x, y) = (real(a), real(b));
    return x.toLowerCase() == y.toLowerCase() if process.platform == "win32" else x == y;
}
