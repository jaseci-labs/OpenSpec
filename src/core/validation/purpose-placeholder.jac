type PurposePlaceholderIssue = any;

glob:priv LEADING_MARKER: str = "^(?:TBD|TODO)(?![\\p{L}\\p{N}\\p{M}_])",
          MARKER_PUNCTUATION: str = "(?=[ \\t]*(?:$|\\n|[:\\-–—.,;()\\[\\]{}]))",
          PURPOSE_HEADER: str = "^ {0,3}##(?!#)[ \\t]+Purpose(?:[ \\t]+#+)?[ \\t]*$",
          TOP_LEVEL_HEADER: str = "^ {0,3}#{1,2}(?!#)[ \\t]+";

def:priv maskedLines(text: str) -> tuple[list[str], list[bool]] {
    lines: list[str] = sub(text, "\\r\\n?", "\n").split("\n");
    return (lines, buildCodeFenceMask(lines));
}

def:priv generatedPlaceholderPrefixIndex(text: str) -> int {
    suffixAt = text.find(PURPOSE_PLACEHOLDER_SUFFIX);
    while suffixAt != -1 {
        prefixAt = text.rfind(
            PURPOSE_PLACEHOLDER_PREFIX, 0, suffixAt + len(PURPOSE_PLACEHOLDER_PREFIX)
        );
        if prefixAt != -1 {
            return prefixAt;
        }
        suffixAt = text.find(PURPOSE_PLACEHOLDER_SUFFIX, suffixAt + 1);
    }
    return -1;
}

def findPurposePlaceholderIssue(overview: str, content: any = None) -> any {
    (lines, fenced) = maskedLines(overview);
    prose: any = "\n".join([lines[i] for i in range(len(lines)) if not fenced[i]]);
    prose = prose.trim();
    leading = found(prose, LEADING_MARKER, "u")
        or found(prose, LEADING_MARKER + MARKER_PUNCTUATION, "iu");
    if not leading and generatedPlaceholderPrefixIndex(prose) == -1 {
        return JsNull;
    }
    return rec(line=None if content is None else findPlaceholderLine(content, leading));
}

def:priv findPlaceholderLine(content: str, leading: bool) -> any {
    (lines, fenced) = maskedLines(content);
    header = next(
        (i for i in range(len(lines)) if not fenced[i] and found(lines[i], PURPOSE_HEADER, "i")), -1
    );
    if header == -1 {
        return None;
    }
    purposeLines: list[tuple[int, str]] = [];
    for i in range(header + 1, len(lines)) {
        text: any = lines[i];
        if fenced[i] {
            continue;
        }
        if found(text, TOP_LEVEL_HEADER) {
            break;
        }
        if leading and text.trim() {
            return i + 1;
        }
        purposeLines.append((i + 1, text));
    }
    purpose = "\n".join([text for (_, text) in purposeLines]);
    prefixAt = -1 if leading else generatedPlaceholderPrefixIndex(purpose);
    offset = purpose[:prefixAt].count("\n");
    return None if prefixAt == -1 or offset >= len(purposeLines) else purposeLines[offset][0];
}
