glob:priv LEVEL_TWO_HEADING: any = rx("^ {0,3}##(?!#)(?:[ \\t]+|[ \\t]*\\r?$)"),
          NUMBERED_GROUP_HEADING: str = "^ {0,3}##[ \\t]+(\\d+)\\.(?:[ \\t]|\\r?$)",
          TASK_ID: str = "^(\\d+(?:\\.\\d+)+(?:[A-Za-z]+)?)(?=\\s|$)";

def:priv groupNumber(group: str) -> str {
    return sub(group, "^0+(?=\\d)", "", "");
}

def findTaskNumberingIssues(documents: list[any]) -> list[any] {
    issues: list[any] = [];
    firstLocationById: dict[str, any] = {};
    for doc in documents {
        lines: list[str] = doc.content.split("\n");
        if not [line for line in lines if found(line, NUMBERED_GROUP_HEADING)] {
            continue;
        }
        currentGroup: any = None;
        for (index, line) in enumerate(lines) {
            if LEVEL_TWO_HEADING.test(line) {
                currentGroup = at(matchOf(line, NUMBERED_GROUP_HEADING), "1");
            }
            if currentGroup is None {
                continue;
            }
            tasks = parseTaskLines(line);
            id = at(matchOf(tasks[0].description, TASK_ID), "1") if tasks else None;
            if not id {
                continue;
            }
            lineNumber = index + 1;
            taskGroup = id.split(".")[0];
            if groupNumber(taskGroup) != groupNumber(currentGroup) {
                issues.append(
                    rec(
                        path=doc.path,
                        line=lineNumber,
                        message=f"Task \"{id}\" is under group {currentGroup}, but its leading number points to group {taskGroup}. Move it to group {taskGroup} or renumber it.",
                    ),
                );
            }
            first = firstLocationById.get(id);
            if first is not None {
                where = f"on line {first.line}"
                    if first.path == doc.path
                    else f"in {first.path} on line {first.line}";
                issues.append(
                    rec(
                        path=doc.path,
                        line=lineNumber,
                        message=f"Task ID \"{id}\" is duplicated; it was first declared {where}.",
                    ),
                );
            } else {
                firstLocationById[id] = rec(path=doc.path, line=lineNumber);
            }
        }
    }
    return issues;
}
