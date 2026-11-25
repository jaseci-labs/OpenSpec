import from "node:fs" { default as fs }
import from "node:path" { default as path }

glob:priv EXTGLOB: str = "[!*+?@]\\([^(]*\\)",
          DUPLICATE_SLASH: str = "(?!^)/{2,}",
          MAX_BRACE_NESTING: int = 16,
          MAX_BRACE_EXPANSIONS: int = 1024,
          LITERAL_BRACE_OPEN: str = "\x00<",
          LITERAL_BRACE_CLOSE: str = "\x00>";

def:priv fail(message: str) -> any {
    return new(globalThis.Error, message);
}

def:priv shown(pattern: str) -> str {
    return f"{pattern[:80]}..." if len(pattern) > 80 else pattern;
}

def:priv isDirectory(target: str) -> bool {
    try {
        return fs.statSync(target).isDirectory();
    } except Exception as e {
        if at(js_error(e), "code") == "ENOENT" {
            return False;
        }
        raise;
    }
}

def:priv assertBraceNesting(pattern: str) {
    stack: list[str] = [];
    size = len(pattern);
    index = 0;
    while index < size {
        ch = pattern[index];
        if ch == "[" {
            brackets = 1;
            while brackets > 0 and index + 1 < size {
                index += 1;
                brackets += 1 if pattern[index] == "[" else -1 if pattern[index] == "]" else 0;
            }
        } elif ch in ["\"", "'", "`"] {
            end = pattern.find(ch, index + 1);
            index = size if end == -1 else end;
        } elif ch in ["{", "("] {
            stack.append(ch);
            if len(stack) > MAX_BRACE_NESTING {
                raise fail(
                    f"Artifact output pattern nests braces more than {MAX_BRACE_NESTING} levels deep: {shown(pattern)}",
                );
            }
        } elif stack and (ch == "}" and stack[-1] == "{" or ch == ")" and stack[-1] == "(") {
            stack.pop();
        }
        index += 1;
    }
}

def:priv isDynamic(text: str) -> bool {
    return "*" in text or "?" in text or "[" in text or found(text, EXTGLOB, "u");
}

def:priv globBase(pattern: str) -> str {
    base: list[str] = [];
    for segment in pattern.split("/")[:-1] {
        if segment == "" {
            continue;
        }
        if isDynamic(segment) {
            break;
        }
        base.append(segment);
    }
    joined = "/".join(base);
    return f"/{joined}" if pattern.startswith("/") else joined or ".";
}

def:priv hasTopLevelExpansion(body: str) -> bool {
    depth = 0;
    for index in range(len(body)) {
        ch = body[index];
        if ch == "{" {
            depth += 1;
        } elif ch == "}" {
            depth = max(0, depth - 1);
        } elif depth == 0 and (ch == "," or body[index:index + 2] == "..") {
            return True;
        }
    }
    return False;
}

def:priv findTopLevelExpansion(pattern: str) -> any {
    stack: list[int] = [];
    for index in range(len(pattern)) {
        if pattern[index] == "{" {
            stack.append(index);
        } elif pattern[index] == "}" and stack {
            start = stack.pop();
            if stack {
                continue;
            }
            body = pattern[start + 1:index];
            if hasTopLevelExpansion(body) {
                return (pattern[:start], body, pattern[index + 1:]);
            }
            nested = findTopLevelExpansion(body);
            if nested {
                return (pattern[:start + 1] + nested[0], nested[1], nested[2] + pattern[index:]);
            }
        }
    }
    return None;
}

def:priv expandArtifactBraces(pattern: str) -> list[str] {
    if "\x00" in pattern {
        raise fail("Artifact output pattern contains a NUL byte");
    }
    pending = [pattern];
    finished: list[str] = [];
    while pending {
        current = pending.pop();
        group = findTopLevelExpansion(current);
        if not group {
            finished.append(
                current.replace(LITERAL_BRACE_OPEN, "{").replace(LITERAL_BRACE_CLOSE, "}")
            );
            continue;
        }
        (pre, body, post) = group;
        wrapped = "{" + body + "}";
        count = len(pending) + len(finished);
        alternatives = need("brace-expansion").expand(
            wrapped, rec(max=max(MAX_BRACE_EXPANSIONS - count, 0) + 1)
        );
        if len(alternatives) == 1 and alternatives[0] == wrapped {
            pending.append(pre + LITERAL_BRACE_OPEN + body + LITERAL_BRACE_CLOSE + post);
            continue;
        }
        if count + len(alternatives) > MAX_BRACE_EXPANSIONS {
            raise fail(
                f"Artifact output pattern expands to more than {MAX_BRACE_EXPANSIONS} patterns: {shown(pattern)}",
            );
        }
        for alternative in alternatives {
            pending.append(pre + alternative + post);
        }
    }
    normalized = [v for v in [sub(f, DUPLICATE_SLASH, "/", "gu") for f in finished] if v];
    return normalized or [pattern];
}

def:priv listDirectoryMatches(directory: str, segment: str) -> list[str] {
    try {
        entries = fs.readdirSync(directory, rec(withFileTypes=True));
    } except Exception as e {
        if at(js_error(e), "code") == "ENOENT" {
            return [];
        }
        raise;
    }
    isMatch = need("picomatch")(segment, rec(dot=False, nobrace=True, noglobstar=True, posix=True));
    return [item.name for item in entries if isMatch(item.name)];
}

def:priv hasBraceExpansion(pattern: str) -> bool {
    openings: list[int] = [];
    for index in range(len(pattern)) {
        if pattern[index] == "{" {
            openings.append(index);
        }
        if pattern[index] == "}"
            and openings
            and found(pattern[openings.pop():index], ",|\\.\\.", "u")
        {
            return True;
        }
    }
    return False;
}

def isGlobPattern(pattern: str) -> bool {
    normalized = FileSystemUtils.toPosixPath(pattern);
    return isDynamic(normalized) or hasBraceExpansion(normalized);
}

def isSpecsArtifactPath(generates: str) -> bool {
    normalized: str = path.posix.normalize(FileSystemUtils.toPosixPath(generates));
    return normalized.startswith("specs/");
}

def resolveArtifactOutputPath(changeDir: str, generates: str) -> str {
    outputPath = path.join(changeDir, generates);
    FileSystemUtils.assertPathWithin(changeDir, outputPath);
    return outputPath;
}

def:priv assertGlobDirectoryTraversal(changeDir: str, segments: list[str]) {
    canonicalChangeDir = FileSystemUtils.canonicalizeExistingPath(changeDir);
    visited: set[str] = set();
    ancestors: set[str] = set();
    def confined(candidate: str) -> str {
        canonical = FileSystemUtils.canonicalizeExistingPath(candidate);
        FileSystemUtils.assertPathWithin(canonicalChangeDir, canonical);
        return canonical;
    }
    def walk(currentDir: str, index: int) {
        if index >= len(segments) {
            return;
        }
        canonicalDir = confined(currentDir);
        key = f"{canonicalDir}\x00{index}";
        if key in ancestors {
            raise fail(
                f"Cannot resolve artifact outputs through a linked directory cycle: {currentDir}"
            );
        }
        if key in visited {
            return;
        }
        visited.add(key);
        ancestors.add(key);
        try {
            segment = segments[index];
            if segment == "**" {
                walk(canonicalDir, index + 1);
            }
            if segment in ["", ".", ".."] {
                walk(confined(path.resolve(canonicalDir, segment or ".")), index + 1);
                return;
            }
            for name in listDirectoryMatches(canonicalDir, "*" if segment == "**" else segment) {
                candidate = path.join(canonicalDir, name);
                if isDirectory(candidate) {
                    walk(confined(candidate), index if segment == "**" else index + 1);
                }
            }
        } finally {
            ancestors.discard(key);
        }
    }
    walk(changeDir, 0);
}

def resolveArtifactOutputs(changeDir: str, generates: str) -> list[str] {
    posix = FileSystemUtils.toPosixPath(generates);
    isGlob = isGlobPattern(generates);
    if isGlob {
        assertBraceNesting(posix);
    }
    outputPath = resolveArtifactOutputPath(changeDir, generates);
    if not isGlob {
        try {
            return [FileSystemUtils.canonicalizeExistingPath(outputPath)]
                if fs.statSync(outputPath).isFile()
                else [];
        } except Exception {
            return [];
        }
    }
    patterns = expandArtifactBraces(sub(posix, DUPLICATE_SLASH, "/", "gu"));
    for pattern in patterns {
        FileSystemUtils.assertPathWithin(changeDir, path.resolve(changeDir, globBase(pattern)));
    }
    for pattern in patterns {
        assertGlobDirectoryTraversal(changeDir, pattern.split("/")[:-1]);
    }
    matches: set[str] = set();
    for found_path in need("tinyglobby").globSync(
        patterns,
        rec(
            cwd=changeDir,
            absolute=True,
            braceExpansion=False,
            expandDirectories=False,
            followSymbolicLinks=True,
            onlyFiles=True,
        ),
    ) {
        normalized = path.normalize(found_path);
        FileSystemUtils.assertPathWithin(changeDir, normalized);
        matches.add(FileSystemUtils.canonicalizeExistingPath(normalized));
    }
    return sorted(matches);
}

def artifactOutputExists(changeDir: str, generates: str) -> bool {
    return len(resolveArtifactOutputs(changeDir, generates)) > 0;
}
