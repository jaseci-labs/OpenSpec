def:priv fenceOf(line: str, tail: str) -> any {
    return matchOf(line, "^\\s*(`{3,}|~{3,})" + tail);
}

def buildCodeFenceMask(lines: list[str]) -> list[bool] {
    mask: list[bool] = [];
    active: any = None;
    for line in lines {
        if active {
            m = fenceOf(line, "\\s*$");
            mask.append(True);
            if m and m[1][0] == active[0] and len(m[1]) >= len(active) {
                active = None;
            }
        } else {
            m = fenceOf(line, "(.*)");
            active = m[1] if m and not (m[1][0] == "`" and m[2].includes("`")) else None;
            mask.append(active is not None);
        }
    }
    return mask;
}
