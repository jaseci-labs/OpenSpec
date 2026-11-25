def escapeYamlValue(value: str) -> str {
    s = value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    return "\""
        + sub(
            s,
            "[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f-\\x9f]",
            lambda (c: str) -> str { f"\\x{ord(c):02x}" },
        )
        + "\"";
}

def formatTagsArray(tags: list[str]) -> str {
    return "[" + ", ".join([escapeYamlValue(t) for t in tags]) + "]";
}

def idField(key: str, prefix: str) -> any {
    return lambda (c: any) -> str { f"{key}: {escapeYamlValue(prefix + c.id)}" };
}

def frontmatter(fields: list[any], body: any = None) -> any {
    def line(c: any, f: any) -> str {
        if kind(f) == "function" {
            return f(c);
        }
        if ":" in f {
            return f;
        }
        return f"{f}: {formatTagsArray(c.tags) if f == 'tags' else escapeYamlValue(c[f])}";
    }
    return lambda (c: any) -> str {
        "---\n"
            + "\n".join([line(c, f) for f in fields])
            + "\n---\n\n"
            + (body(c.body) if body else c.body)
            + "\n"
    };
}
