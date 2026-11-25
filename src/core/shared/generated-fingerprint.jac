import from "node:crypto" { createHash }

glob:priv GENERATED_VERSION: str = "^(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)(?:-(?:(?:0|[1-9]\\d*|\\d*[A-Za-z-][0-9A-Za-z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$",
          RELEASED: set[str] = set(RELEASED_GENERATED_FINGERPRINTS);

def normalizeGeneratedFile(content: str) -> str {
    return sub(sub(content, "^\\uFEFF", "", ""), "\\r\\n", "\n");
}

def:priv versionLine(
    line: str, prefix: str, doubleQuoted: any, singleQuoted: any, bare: any
) -> str {
    version = doubleQuoted ?? singleQuoted ?? bare;
    return f'{prefix}"<generated-version>"'
        if version and found(version, GENERATED_VERSION)
        else line;
}

def normalizeGeneratedContent(content: str) -> str {
    normalized = normalizeGeneratedFile(content);
    head = matchOf(normalized, "^---\\n[\\s\\S]*?\\n---(?:\\n|$)");
    if not head {
        return normalized;
    }
    frontmatter: str = head[0];
    return sub(
        frontmatter,
        "^([ \\t]*generatedBy:[ \\t]*)(?:\"([^\"\\n]+)\"|'([^'\\n]+)'|([^\\s\"'#]+))[ \\t]*$",
        versionLine,
        "m",
    )
        + normalized[len(frontmatter):];
}

def fingerprintGeneratedContent(content: str) -> str {
    return createHash("sha256").update(normalizeGeneratedContent(content), "utf8").digest(
        "hex"
    )[:16];
}

def extractOpenSpecBlock(content: str) -> any {
    return findMarkerBlock(
        content.replace("\r\n", "\n"), "<!-- OPENSPEC:START -->", "<!-- OPENSPEC:END -->"
    );
}

def isReleasedGeneratedContent(content: str) -> bool {
    return fingerprintGeneratedContent(content) in RELEASED;
}

def hasReleasedOpenSpecBlock(content: str) -> bool {
    block = extractOpenSpecBlock(content);
    return block is not None and isReleasedGeneratedContent(block);
}
