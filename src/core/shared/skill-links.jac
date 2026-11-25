import from "node:path" { default as path }
import from "node:fs" { default as fs }

type SkillLinkSpot = any;

glob:priv OS_JUNK: list[str] = [".DS_Store", "Thumbs.db", "desktop.ini"];

def isOsJunk(name: str) -> bool {
    return name in OS_JUNK or name.startswith("._");
}

def skillLinkText(linkPath: str, targetDir: str) -> str {
    projectRoot = path.dirname(path.dirname(path.dirname(targetDir)));
    target = path.join(realOrSelf(projectRoot), path.relative(projectRoot, targetDir));
    return path.relative(realOrSelf(path.dirname(linkPath)), target);
}

def:priv realOrSelf(p: str) -> str {
    try {
        return fs.realpathSync(p);
    } except Exception {
        return path.resolve(p);
    }
}

def:priv linkPointsTo(linkPath: str, linked: str, targetDir: str) -> bool {
    normalized = linked.replace("\\", "/");
    if path.resolve(path.dirname(linkPath), normalized) == path.resolve(targetDir)
        or path.resolve(realOrSelf(path.dirname(linkPath)), normalized)
            == path.resolve(realOrSelf(path.dirname(targetDir)), path.basename(targetDir))
    {
        return True;
    }
    try {
        return fs.realpathSync(linkPath) == fs.realpathSync(targetDir);
    } except Exception {
        return False;
    }
}

def:priv linkOf(view: any, p: str) -> any {
    return None if missing(view["linkTarget"]) else view.linkTarget(p);
}

def:priv classifyContent(view: any, skillFile: str, sharedContent: any) -> str {
    try {
        content = view.read(skillFile);
    } except Exception {
        return "user";
    }
    normalized = normalizeGeneratedContent(content);
    for text in [sharedContent] if kind(sharedContent) == "string" else sharedContent {
        if normalizeGeneratedContent(text) == normalized {
            return "copy";
        }
    }
    return "released" if isReleasedGeneratedContent(content) else "user";
}

def classifySkillLinkSpot(
    linkPath: str, targetDir: str, sharedContent: any, view: any = DISK_VIEW
) -> str {
    linked = linkOf(view, linkPath);
    if linked is not None {
        return "link" if linkPointsTo(linkPath, linked, targetDir) else "user";
    }
    if not view.exists(linkPath) {
        return "missing";
    }
    if not view.isDirectory(linkPath) {
        return "released" if isCheckedOutLink(linkPath, targetDir, view) else "user";
    }
    try {
        entries = [
            name
            for name in (
                fs.readdirSync(linkPath)
                    if missing(view["listDirectory"])
                    else view.listDirectory(linkPath)
            )
            if not isOsJunk(name)
        ];
    } except Exception {
        return "user";
    }
    if not entries {
        return "missing";
    }
    skillFile = path.join(linkPath, "SKILL.md");
    if len(entries) != 1
        or entries[0] != "SKILL.md"
        or linkOf(view, skillFile) is not None
        or view.isDirectory(skillFile)
    {
        return "user";
    }
    return classifyContent(view, skillFile, sharedContent);
}

def isCheckedOutLink(filePath: str, targetDir: str, view: any = DISK_VIEW) -> bool {
    try {
        text: any = view.read(filePath);
    } except Exception {
        return False;
    }
    linked = text.trim();
    return len(text) <= 1024
        and linked != ""
        and "\n" not in linked
        and linkPointsTo(filePath, linked, targetDir);
}

def classifySkillFile(skillDir: str, sharedContent: any, view: any = DISK_VIEW) -> str {
    skillFile = path.join(skillDir, "SKILL.md");
    if linkOf(view, skillDir) is not None or linkOf(view, skillFile) is not None {
        return "user";
    }
    if not view.exists(skillFile) {
        return "missing";
    }
    if view.isDirectory(skillFile) {
        return "user";
    }
    return classifyContent(view, skillFile, sharedContent);
}

def createSkillLink(linkPath: str, targetDir: str, symlink: any = None) -> str {
    fs.mkdirSync(path.dirname(linkPath), rec(recursive=True));
    if fs.existsSync(linkPath) or isSymlink(linkPath) {
        fs.rmSync(linkPath, rec(recursive=True, force=True));
    }
    try {
        (symlink ?? fs.symlinkSync)(skillLinkText(linkPath, targetDir), linkPath, "dir");
        return "link";
    } except Exception {
        fs.mkdirSync(linkPath, rec(recursive=True));
        fs.copyFileSync(path.join(targetDir, "SKILL.md"), path.join(linkPath, "SKILL.md"));
        return "copy";
    }
}

def:priv isSymlink(filePath: str) -> bool {
    try {
        return fs.lstatSync(filePath).isSymbolicLink();
    } except Exception {
        return False;
    }
}
