def shellSingleQuote(value: str) -> str {
    return "'" + value.replace("'", "'\\''") + "'";
}
