import from "node:path" { default as path }
import from "node:fs" { default as fs }
import from "node:os" { default as os }
import from "node:process" { default as process }

type UpdatePlanChange = any;

type UpdatePlan = any;

type UpdateFileOps = any;

glob:priv GONE: any = globalThis.Symbol("planned away"),
          DIR: any = globalThis.Symbol("staged directory");

async def:priv writeOut(filePath: str, content: str) {
    await FileSystemUtils.writeFile(filePath, content);
}

async def:priv unlink(filePath: str) {
    await fs.promises.unlink(filePath);
}

async def:priv removeTree(dirPath: str) {
    await fs.promises.rm(dirPath, rec(recursive=True, force=True));
}

async def:priv removeEmpty(dirPath: str) {
    await fs.promises.rmdir(dirPath);
}

async def:priv link(linkPath: str, targetDir: str) {
    createSkillLink(linkPath, targetDir);
}

glob realFileOps: any = rec(
    writeFile=writeOut,
    removeFile=unlink,
    removeDirectory=removeTree,
    removeEmptyDirectory=removeEmpty,
    linkSkill=link,
);

def:priv chain(start: str) -> list[str] {
    out = [start];
    while path.dirname(out[-1]) != out[-1] {
        out.append(path.dirname(out[-1]));
    }
    return out;
}

def:priv unique(items: any) -> list[any] {
    return globalThis.Array.from(new(globalThis.Set, items));
}

def:priv isLink(target: str) -> bool {
    try {
        return fs.lstatSync(target).isSymbolicLink();
    } except Exception {
        return False;
    }
}

def:priv errnoError(code: str, description: str, syscall: str, target: str) -> any {
    return globalThis.Object.assign(
        new(globalThis.Error, f"{code}: {description}, {syscall} '{target}'"),
        rec(code=code, syscall=syscall, path=target),
    );
}

def:priv originalEntry(target: str) -> any {
    descriptor: any = None;
    try {
        descriptor = fs.openSync(
            target, fs.constants.O_RDONLY | (at(fs.constants, "O_NONBLOCK") ?? 0)
        );
        if fs.fstatSync(descriptor).isFile() {
            return fs.readFileSync(descriptor, "utf-8");
        }
    } except Exception {} finally {
        if descriptor is not None {
            fs.closeSync(descriptor);
        }
    }
    try {
        return "symlink:" + fs.readlinkSync(target);
    } except Exception {
        return None;
    }
}

def:priv listFilesRecursively(dirPath: str) -> list[str] {
    try {
        entries = fs.readdirSync(dirPath, rec(withFileTypes=True));
    } except Exception {
        return [];
    }
    files: list[str] = [];
    for ent in entries {
        full = path.join(dirPath, ent.name);
        if ent.isDirectory() {
            files.extend(listFilesRecursively(full));
        } else {
            files.append(full);
        }
    }
    return files;
}

def:priv inside(relative: str) -> bool {
    return relative != "" and not relative.startswith("..") and not path.isAbsolute(relative);
}

obj UpdatePlanRecorder(globalThis.Object) {
    def init(projectPath: str) {
        super.init();
        self.projectPath = projectPath;
        self.notes = [];
        self.failures = [];
        self.staged = {};
        self.touched = {};
        self.links = {};
        self.view = rec(
            exists=lambda (p: str) -> bool { self.kindAt(p) != "missing" },
            isDirectory=lambda (p: str) -> bool { self.kindAt(p) == "directory" },
            listDirectory=lambda (p: str) -> any { self.listDirectory(p) },
            linkTarget=lambda (p: str) -> any { self.linkTarget(p) },
            read=lambda (p: str) -> any { self.read(p) },
        );
    }

    async def writeFile(filePath: str, content: str, tool: str) {
        target = path.resolve(filePath);
        self.probeWrite(target);
        self.stage(target, content, tool);
    }

    async def removeFile(filePath: str, tool: str) {
        target = path.resolve(filePath);
        self.probeRemove(target);
        self.stage(target, GONE, tool);
    }

    async def removeEmptyDirectory(dirPath: str) {
        self.staged[path.resolve(dirPath)] = GONE;
    }

    async def linkSkill(linkPath: str, targetDir: str, tool: str) {
        to = path.resolve(linkPath);
        source = path.resolve(targetDir);
        if isLink(to) and to not in self.links and self.stagedEntry(to) is None {
            if path.resolve(path.dirname(to), fs.readlinkSync(to)) == source {
                return;
            }
            self.stage(to, GONE, tool);
        } elif self.entryKind(to)[0] != "missing" {
            self.unstage(self.filesUnder(to), tool);
            self.staged[to] = GONE;
        }
        self.probeCreatableIn(path.dirname(to));
        self.links[to] = source;
        self.touched[to] = tool;
    }

    async def removeDirectory(dirPath: str, tool: str) {
        target = path.resolve(dirPath);
        if target in self.links or isLink(target) {
            self.links.pop(target, None);
            self.stage(target, GONE, tool);
            return;
        }
        self.unstage(self.filesUnder(target), tool);
        for (file, ent) in list(self.staged.items()) {
            if ent is DIR and file.startswith(target + path.sep) {
                self.staged[file] = GONE;
            }
        }
        self.staged[target] = GONE;
    }

    async def moveFile(source: str, destination: str, tool: str) {
        origin = path.resolve(source);
        to = path.resolve(destination);
        self.probeCreatableIn(path.dirname(to));
        if self.entryKind(origin)[0] == "directory" {
            if self.entryKind(to)[0] != "missing" {
                raise errnoError("ENOTEMPTY", "directory not empty", "rename", to);
            }
            files = self.filesUnder(origin);
            contents: list[tuple[str, str]] = [(f, self.read(f)) for f in files];
            self.unstage(files, tool);
            self.staged[origin] = GONE;
            self.staged[to] = DIR;
            for (f, content) in contents {
                self.stage(path.join(to, path.relative(origin, f)), content, tool);
            }
            return;
        }
        content = self.read(origin);
        self.probeWrite(to);
        self.probeRemove(origin);
        self.stage(origin, GONE, tool);
        self.stage(to, content, tool);
    }

    def throughLinks(target: str) -> str {
        for current in chain(target) {
            if current in self.links {
                return self.throughLinks(
                    path.join(self.links[current], path.relative(current, target))
                );
            }
        }
        return target;
    }

    def kindAt(filePath: str) -> str {
        return self.entryKind(self.throughLinks(path.resolve(filePath)))[0];
    }

    def listDirectory(dirPath: str) -> list[any] {
        directory = self.throughLinks(path.resolve(dirPath));
        prefix = directory + path.sep;
        names = [
            path.relative(directory, f).split(path.sep)[0]
            for f in self.filesUnder(directory)
        ];
        try {
            names.extend([
                name
                for name in fs.readdirSync(directory)
                if self.stagedEntry(path.join(directory, name)) is not GONE
            ]);
        } except Exception {}
        names.extend([
            path.relative(directory, key).split(path.sep)[0]
            for key in list(self.staged.keys()) + list(self.links.keys())
            if key.startswith(prefix) and self.stagedEntry(key) is not GONE
        ]);
        return unique(names);
    }

    def linkTarget(filePath: str) -> any {
        target = path.resolve(filePath);
        if target in self.links {
            return self.links[target];
        }
        return None if self.stagedEntry(target) is not None else DISK_VIEW.linkTarget(target);
    }

    def read(filePath: str) -> any {
        target = self.throughLinks(path.resolve(filePath));
        staged = self.stagedEntry(target);
        if staged is None {
            return fs.readFileSync(target, "utf-8");
        }
        if staged is GONE {
            raise errnoError("ENOENT", "no such file or directory", "open", target);
        }
        if staged is DIR {
            raise errnoError("EISDIR", "illegal operation on a directory", "read", target);
        }
        return staged;
    }

    def addNote(code: str, message: str) {
        if code not in [note.code for note in self.notes] {
            self.notes.append(rec(code=code, message=message));
        }
    }

    def addFailure(tool: str, error: str) {
        self.failures.append(rec(tool=tool, error=error));
    }

    def getPlan -> any {
        byPath: dict[str, any] = {};
        for (filePath, tool) in self.touched.items() {
            before = originalEntry(filePath);
            after = f"symlink:{skillLinkText(filePath, self.links[filePath])}"
                if filePath in self.links
                else self.stagedEntry(filePath);
            if after is None or after is DIR {
                continue;
            }
            action = (None if before is None else "delete")
                if after is GONE
                else ("add" if before is None else ("update" if before != after else None));
            if action is not None {
                display = self.toDisplayPath(filePath);
                byPath[display] = rec(path=display, action=action, tool=tool);
            }
        }
        changes = globalThis.Array.prototype.sort.call(
            list(byPath.values()), lambda (a: any, b: any) -> int { a.path.localeCompare(b.path) }
        );
        return rec(changes=changes, notes=list(self.notes), failures=list(self.failures));
    }

    def stage(target: str, ent: any, tool: str) {
        self.staged[target] = ent;
        self.touched[target] = tool;
    }

    def unstage(files: list[str], tool: str) {
        for f in files {
            self.stage(f, GONE, tool);
        }
    }

    def stagedEntry(target: str) -> any {
        for current in chain(target) {
            staged = self.staged.get(current);
            if staged is GONE or (staged is not None and current == target) {
                return staged;
            }
        }
        return None;
    }

    def hasStagedDescendant(directory: str) -> bool {
        prefix = directory if directory.endswith(path.sep) else directory + path.sep;
        for key in list(self.staged.keys()) {
            ent = self.stagedEntry(key) if key.startswith(prefix) else None;
            if ent is not None and ent is not GONE {
                return True;
            }
        }
        return False;
    }

    def filesUnder(directory: str) -> list[any] {
        prefix = directory + path.sep;
        return unique(
            [f for f in listFilesRecursively(directory) if self.stagedEntry(f) is not GONE] + [
                key
                for key in list(self.staged.keys())
                if key.startswith(prefix) and kind(self.stagedEntry(key)) == "string"
            ],
        );
    }

    def entryKind(target: str) -> tuple[str, bool] {
        staged = self.stagedEntry(target);
        if staged is DIR {
            return ("directory", False);
        }
        if kind(staged) == "string" {
            return ("file", fs.existsSync(target));
        }
        if staged is None {
            try {
                return ("directory" if fs.statSync(target).isDirectory() else "file", True);
            } except Exception as e {
                if at(js_error(e), "code") not in ["ENOENT", "ENOTDIR"] {
                    raise js_error(e);
                }
            }
        }
        return ("directory" if self.hasStagedDescendant(target) else "missing", False);
    }

    def probeWrite(target: str) {
        (ent, onDisk) = self.entryKind(target);
        if ent == "directory" {
            raise errnoError("EISDIR", "illegal operation on a directory", "open", target);
        }
        if ent == "file" {
            if onDisk {
                fs.accessSync(target, fs.constants.W_OK);
            }
            return;
        }
        self.probeCreatableIn(path.dirname(target));
    }

    def probeRemove(target: str) {
        (ent, onDisk) = self.entryKind(target);
        if ent == "directory" {
            raise errnoError("EISDIR", "illegal operation on a directory", "unlink", target);
        }
        if ent == "file" and onDisk {
            fs.accessSync(path.dirname(target), fs.constants.W_OK);
        }
    }

    def probeCreatableIn(directory: str) {
        for current in chain(directory) {
            (ent, onDisk) = self.entryKind(current);
            if ent == "file" {
                raise errnoError("ENOTDIR", "not a directory", "mkdir", current);
            }
            if ent == "directory" {
                if onDisk {
                    fs.accessSync(current, fs.constants.W_OK);
                }
                return;
            }
        }
    }

    def toDisplayPath(filePath: str) -> str {
        absolute = path.resolve(filePath);
        relative = path.relative(self.projectPath, absolute);
        if inside(relative) {
            return FileSystemUtils.toPosixPath(relative);
        }
        home = at(process.env, "USERPROFILE") ?? at(process.env, "HOME") ?? os.homedir();
        fromHome = path.relative(home, absolute);
        if inside(fromHome) {
            return "~/" + FileSystemUtils.toPosixPath(fromHome);
        }
        return FileSystemUtils.toPosixPath(absolute);
    }
}

def formatUpdatePlan(plan: any) -> str {
    lines: list[str] = [];
    if not plan.changes {
        lines.append(
            "No file in this folder would change."
                if "global-skills" in [note.code for note in plan.notes]
                else "No changes: skills are up to date.",
        );
    } else {
        lines.append(f"{len(plan.changes)} file(s) would change:");
        width = max([len(change.action) for change in plan.changes]);
        for change in plan.changes {
            lines.append(f"  {change.action.padEnd(width)}  {change.path}  ({change.tool})");
        }
    }
    for note in plan.notes {
        lines.extend(["", f"Note: {note.message}"]);
    }
    for failure in plan.failures {
        lines.extend(["", f"Would fail: {failure.tool} ({failure.error})"]);
    }
    return "\n".join(lines);
}

with entry {
    new(
        globalThis.Function,
        "C",
        "for (const k of ['writeFile', 'removeFile', 'removeEmptyDirectory', 'linkSkill', 'removeDirectory', 'moveFile']) { const f = C.prototype[k]; C.prototype[k] = function (...a) { return f.apply(this, a).then(); }; }",
    )(UpdatePlanRecorder);
}
