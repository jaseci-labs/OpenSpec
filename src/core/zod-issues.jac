def formatZodIssues(error: any, fallbackLocation: str = "root") -> str {
    return "; ".join([
        f"{i.path.join('.') if len(i.path) else fallbackLocation}: {i.message}"
        for i in error.issues
    ]);
}
