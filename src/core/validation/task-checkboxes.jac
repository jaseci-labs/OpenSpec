glob:priv LIST_ITEM: any = rx("^\\s*(?:[-*+]|\\d{1,9}[.)])\\s+\\S"),
          FENCE: str = "^ {0,3}(`{3,}|~{3,})(.*)",
          FRONT_MATTER: any = rx("^-{3}\\s*$"),
          CODE_BLOCK_COLUMN: int = 4,
          COMMENT_OPEN: str = "<!--",
          COMMENT_CLOSE: str = "-->",
          MISSING_CHECKBOX_MESSAGE: str = "This change counts as 0 tasks: no line in its tracked task files is a checkbox, so \"openspec list\" and \"openspec status\" report no work and \"openspec archive\" has nothing to flag as incomplete. Write each task as \"- [ ] 1.1 Description\".";

def findMissingTaskCheckboxIssues(documents: list[any]) -> list[any] {
    for doc in documents {
        if parseTaskLines(doc.content) {
            return [];
        }
    }
    issues: list[any] = [];
    for doc in documents {
        line = findFirstListItemLine(doc.content);
        if line is not None {
            issues.append(rec(path=doc.path, line=line, message=MISSING_CHECKBOX_MESSAGE));
        }
    }
    return issues;
}

def:priv indentColumns(line: str) -> int {
    column = 0;
    for char in line {
        if char == " " {
            column += 1;
        } elif char == "\t" {
            column += CODE_BLOCK_COLUMN - column % CODE_BLOCK_COLUMN;
        } else {
            break;
        }
    }
    return column;
}

def:priv findFirstListItemLine(content: str) -> any {
    lines = content.split("\n");
    openFence: any = None;
    inComment = False;
    for index in range(skipFrontMatter(lines), len(lines)) {
        line: any = lines[index];
        if inComment {
            if COMMENT_CLOSE in line {
                inComment = False;
            }
            continue;
        }
        fence = matchOf(line, FENCE);
        if not missing(fence) {
            run: str = fence[1];
            info: any = fence[2];
            if openFence is None {
                openFence = (run[0], len(run));
            } elif run[0] == openFence[0] and len(run) >= openFence[1] and info.trim() == "" {
                openFence = None;
            }
            continue;
        }
        if openFence is not None {
            continue;
        }
        if line.trimStart().startsWith(COMMENT_OPEN) {
            if COMMENT_CLOSE not in line[line.index(COMMENT_OPEN) + len(COMMENT_OPEN):] {
                inComment = True;
            }
            continue;
        }
        if LIST_ITEM.test(line) and indentColumns(line) < CODE_BLOCK_COLUMN {
            return index + 1;
        }
    }
    return None;
}

def:priv skipFrontMatter(lines: list[str]) -> int {
    first: any = sub(lines[0], "^\\uFEFF", "", "") if lines else "";
    if not lines or not FRONT_MATTER.test(first.trimEnd()) {
        return 0;
    }
    for index in range(1, len(lines)) {
        line: any = lines[index];
        if FRONT_MATTER.test(line.trimEnd()) {
            return index + 1;
        }
    }
    return 0;
}
