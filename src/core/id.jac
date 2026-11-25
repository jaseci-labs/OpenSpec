glob KEBAB_ID_REGEX: any = rx("^[a-z0-9]+(?:-[a-z0-9]+)*$", "u"),
     KEBAB_ID_DESCRIPTION: str = "must be kebab-case with lowercase letters, numbers, and single hyphen separators",
     KEBAB_ID_FIX: str = "Use kebab-case with lowercase letters, numbers, and single hyphen separators.";

def isKebabId(value: str) -> bool {
    return KEBAB_ID_REGEX.test(value);
}

def toKebabCase(value: str) -> str {
    s = sub(sub(value, "([a-z0-9])([A-Z])", "$1-$2"), "([A-Z])([A-Z][a-z])", "$1-$2");
    return sub(sub(s, "[^a-zA-Z0-9]+", "-"), "^-+|-+$", "").lower();
}

def folderStyleNameProblem(value: str, label: str) -> any {
    if not value {
        return f"{label} must not be empty";
    }
    if value in [".", ".."] {
        return f"{label} must not be '{value}'";
    }
    if "/" in value or "\\" in value {
        return f"{label} must not contain path separators";
    }
    return JsNull;
}
