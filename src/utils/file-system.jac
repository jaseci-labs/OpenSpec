import from "fs" { default as nodeFs }
import from "path" { default as path }
import from "node:process" { default as process }
import from "node:console" { default as console }

glob:priv fs: any = nodeFs.promises;

def:priv fail(message: str) -> any {
    return new(globalThis.Error, message);
}

def:priv codeOf(e: any) -> any {
    return at(js_error(e), "code");
}

async def:priv hasWritableModeAndAccess(targetPath: str) -> bool {
    try {
        stats = await fs.stat(targetPath);
        isDir = stats.isDirectory();
        if process.platform != "win32"
            and (not stats.mode & 0o222 or (isDir and not stats.mode & 0o111))
        {
            return False;
        }
        await fs.access(
            targetPath,
            (nodeFs.constants.W_OK | nodeFs.constants.X_OK) if isDir else nodeFs.constants.W_OK,
        );
        return True;
    } except Exception {
        return False;
    }
}

def:priv findMarkerIndex(content: str, marker: str, fromIndex: int = 0) -> int {
    i = content.find(marker, fromIndex);
    while i != -1 {
        end = content.find("\n", i + len(marker));
        around = content[content.rfind("\n", 0, i) + 1:i]
            + content[i + len(marker):len(content) if end == -1 else end];
        if found(around, "^[ \\t\\r]*$") {
            return i;
        }
        i = content.find(marker, i + len(marker));
    }
    return -1;
}

def:priv markerSpan(content: str, startMarker: str, endMarker: str) -> tuple[int, int] {
    start = findMarkerIndex(content, startMarker);
    return (
        start,
        findMarkerIndex(content, endMarker, 0 if start == -1 else start + len(startMarker)),
    );
}

def:priv isSymbolicLink(targetPath: str) -> bool {
    try {
        return nodeFs.lstatSync(targetPath).isSymbolicLink();
    } except Exception as e {
        if codeOf(e) != "ENOENT" {
            raise;
        }
        return False;
    }
}

def:priv isPathWithin(allowedDirectory: str, targetPath: str) -> bool {
    relative: str = path.relative(allowedDirectory, targetPath);
    return relative == ""
        or (
            relative != ".."
            and not relative.startswith(f"..{path.sep}")
            and not path.isAbsolute(relative)
        );
}

def:priv canonicalizePotentialPath(targetPath: str) -> str {
    existing = targetPath;
    missingSegments: list[str] = [];
    while True {
        try {
            nodeFs.lstatSync(existing);
            return path.resolve(nodeFs.realpathSync.native(existing), *missingSegments);
        } except Exception as e {
            if codeOf(e) != "ENOENT" {
                raise;
            }
        }
        if isSymbolicLink(existing) {
            raise fail(f"Cannot verify dangling symbolic link: {existing}");
        }
        parent = path.dirname(existing);
        if parent == existing {
            raise fail(f"Cannot resolve an existing parent for {targetPath}");
        }
        missingSegments.insert(0, path.basename(existing));
        existing = parent;
    }
}

async def:priv findFirstExistingDirectory(dirPath: str) -> any {
    current = dirPath;
    while True {
        try {
            if (await fs.stat(current)).isDirectory() {
                return current;
            }
            console.debug(f"Path component {current} exists but is not a directory");
            return None;
        } except Exception as e {
            parent = path.dirname(current);
            if codeOf(e) != "ENOENT" {
                console.debug(f"Error checking directory {current}: {js_error(e).message}");
                return None;
            }
            if parent == current {
                return None;
            }
            current = parent;
        }
    }
}

obj FileSystemUtils(globalThis.Object) {
    static def toPosixPath(p: str) -> str {
        return p.replace("\\", "/");
    }

    static def canonicalizeExistingPath(targetPath: str) -> str {
        try {
            return nodeFs.realpathSync.native(targetPath);
        } except Exception {
            try {
                return nodeFs.realpathSync(targetPath);
            } except Exception {
                return path.resolve(targetPath);
            }
        }
    }

    static def assertPathWithin(allowedDirectory: str, targetPath: str) {
        directory = path.resolve(allowedDirectory);
        target = path.resolve(targetPath);
        if not (
            isPathWithin(directory, target)
            and isPathWithin(
                canonicalizePotentialPath(directory), canonicalizePotentialPath(target)
            )
        ) {
            raise fail(f"Path is outside the allowed directory: {targetPath}");
        }
    }

    static def assertPathWithinAllowingLinkedLeaf(allowedDirectory: str, targetPath: str) {
        target = path.resolve(targetPath);
        if not isSymbolicLink(target) {
            FileSystemUtils.assertPathWithin(allowedDirectory, target);
            return;
        }
        FileSystemUtils.assertPathWithin(allowedDirectory, path.dirname(target));
        nodeFs.realpathSync.native(target);
    }

    static def resolveProjectArtifactPath(projectPath: str, artifactPath: str) -> str {
        if path.isAbsolute(artifactPath) {
            raise fail(f"Refusing to manage an artifact outside the project: {artifactPath}");
        }
        targetPath = path.join(projectPath, artifactPath);
        FileSystemUtils.assertPathWithin(projectPath, targetPath);
        return targetPath;
    }

    static def assertProjectArtifactPath(projectPath: str, targetPath: str) {
        FileSystemUtils.assertPathWithin(projectPath, targetPath);
    }

    static def joinPath(basePath: str, *segments: str) -> str {
        parts = [
            part
            for segment in segments
            for part in segment.replace("\\", "/").split("/")
            if part
        ];
        if found(basePath, "^[A-Za-z]:[\\\\/]") or basePath.startswith("\\") {
            return path.win32.join(path.win32.normalize(basePath), *parts);
        }
        return path.posix.join(basePath.replace("\\", "/"), *parts);
    }

    static async def createDirectory(dirPath: str) {
        await fs.mkdir(dirPath, rec(recursive=True));
    }

    static async def fileExists(filePath: str) -> bool {
        try {
            await fs.access(filePath);
            return True;
        } except Exception as e {
            if codeOf(e) != "ENOENT" {
                console.debug(
                    f"Unable to check if file exists at {filePath}: {js_error(e).message}"
                );
            }
            return False;
        }
    }

    static async def canWriteFile(filePath: str) -> bool {
        try {
            stats = await fs.stat(filePath);
            return not (stats.isDirectory() or stats.isFile())
                or await hasWritableModeAndAccess(filePath);
        } except Exception as e {
            if codeOf(e) != "ENOENT" {
                console.debug(
                    f"Unable to determine write permissions for {filePath}: {js_error(e).message}"
                );
                return False;
            }
        }
        existingDir = await findFirstExistingDirectory(path.dirname(filePath));
        return existingDir is not None and await hasWritableModeAndAccess(existingDir);
    }

    static async def directoryExists(dirPath: str) -> bool {
        try {
            return (await fs.stat(dirPath)).isDirectory();
        } except Exception as e {
            if codeOf(e) != "ENOENT" {
                console.debug(
                    f"Unable to check if directory exists at {dirPath}: {js_error(e).message}"
                );
            }
            return False;
        }
    }

    static async def writeFile(filePath: str, content: str) {
        await FileSystemUtils.createDirectory(path.dirname(filePath));
        await fs.writeFile(filePath, content, "utf-8");
    }

    static async def readFile(filePath: str) -> str {
        return await fs.readFile(filePath, "utf-8");
    }

    static async def updateFileWithMarkers(
        filePath: str, content: str, startMarker: str, endMarker: str
    ) {
        block = f"{startMarker}\n{content}\n{endMarker}";
        if not await FileSystemUtils.fileExists(filePath) {
            await FileSystemUtils.writeFile(filePath, block);
            return;
        }
        existing = await FileSystemUtils.readFile(filePath);
        (start, end) = markerSpan(existing, startMarker, endMarker);
        if (start == -1) != (end == -1) {
            raise fail(
                f"Invalid marker state in {filePath}. Found start: {globalThis.String(start != -1)}, Found end: {globalThis.String(end != -1)}",
            );
        }
        updated = f"{block}\n\n{existing}"
            if start == -1
            else existing[:start] + block + existing[end + len(endMarker):];
        await FileSystemUtils.writeFile(filePath, matchLineEnding(updated, existing));
    }

    static async def ensureWritePermissions(dirPath: str) -> bool {
        try {
            if not await FileSystemUtils.directoryExists(dirPath) {
                parentDir = path.dirname(dirPath);
                if not await FileSystemUtils.directoryExists(parentDir) {
                    await FileSystemUtils.createDirectory(parentDir);
                }
                return await FileSystemUtils.ensureWritePermissions(parentDir);
            }
            suffix: str = globalThis.Math.random().toString(36).slice(2);
            testFile = path.join(dirPath, f".openspec-test-{globalThis.Date.now()}-{suffix}");
            await fs.writeFile(testFile, "");
            for attempt in range(3) {
                try {
                    await fs.unlink(testFile);
                    break;
                } except Exception as e {
                    if attempt == 2 {
                        console.debug(
                            f"Could not clean up test file {testFile}: {js_error(e).message}"
                        );
                    } else {
                        await new(
                            globalThis.Promise,
                            lambda (resolve: any) -> any { globalThis.setTimeout(resolve, 50) },
                        );
                    }
                }
            }
            return True;
        } except Exception as e {
            console.debug(f"Insufficient permissions to write to {dirPath}: {js_error(e).message}");
            return False;
        }
    }
}

with entry {
    new(
        globalThis.Function,
        "C",
        "const raw = (k) => Object.getOwnPropertyDescriptor(C, k).value;"
            + "const join = raw('joinPath'); C.joinPath = (base, ...segments) => join(base, segments.flat());"
            + "for (const k of ['createDirectory', 'fileExists', 'canWriteFile', 'directoryExists', 'writeFile',"
            + " 'readFile', 'updateFileWithMarkers', 'ensureWritePermissions']) {"
            + " const f = raw(k); C[k] = (...args) => f(...args).then(); }",
    )(FileSystemUtils);
}

def findMarkerBlock(content: str, startMarker: str, endMarker: str) -> any {
    (start, end) = markerSpan(content, startMarker, endMarker);
    return None if start == -1 or end == -1 else content[start:end + len(endMarker)];
}

def removeMarkerBlock(content: str, startMarker: str, endMarker: str) -> str {
    (start, end) = markerSpan(content, startMarker, endMarker);
    if start == -1 or end == -1 or end <= start {
        return content;
    }
    lineEnd = content.find("\n", end + len(endMarker));
    newline = detectLineEnding(content) ?? "\n";
    collapsed: any = sub(
        content[:content.rfind("\n", 0, start) + 1]
            + content[len(content) if lineEnd == -1 else lineEnd + 1:],
        "(\\r?\\n){3,}",
        newline + newline,
    );
    result = collapsed.trimEnd();
    return result + newline if result else "";
}
