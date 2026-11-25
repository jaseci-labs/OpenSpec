def detectLineEnding(content: str) -> any {
    crlf = content.count("\r\n");
    lf = content.count("\n") - crlf;
    if crlf == 0 and lf == 0 {
        return None;
    }
    return "\r\n" if crlf >= lf else "\n";
}

def applyLineEnding(content: str, ending: str) -> str {
    normalized = content.replace("\r\n", "\n");
    return normalized if ending == "\n" else normalized.replace("\n", "\r\n");
}

def matchLineEnding(content: str, original: str) -> str {
    ending = detectLineEnding(original);
    return content if ending is None else applyLineEnding(content, ending);
}
