def:priv controls(value: str) -> str {
    return sub(
        value,
        "[\\u0000-\\u0008\\u000b\\u000c\\u000e-\\u001f\\u007f]",
        lambda (c: str) -> str { f"\\u{ord(c):04x}" },
    );
}

def escapeTomlBasicString(value: str) -> str {
    return controls(
        value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace(
            "\r", "\\r"
        ).replace("\t", "\\t"),
    );
}

def escapeTomlMultilineBasicString(value: str) -> str {
    return controls(
        value.replace("\r\n", "\n").replace("\\", "\\\\").replace("\"\"\"", "\"\"\\\"").replace(
            "\r", "\\r"
        ),
    );
}

def tomlCommandFile(content: any) -> str {
    return f"description = \"{escapeTomlBasicString(content.description)}\"\n\nprompt = \"\"\"\n{escapeTomlMultilineBasicString(content.body)}\n\"\"\"\n";
}
