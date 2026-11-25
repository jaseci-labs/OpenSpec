def formatLocalDate(date: any = None) -> str {
    d = date ?? new(globalThis.Date);
    return f"{d.getFullYear()}-{d.getMonth() + 1:02d}-{d.getDate():02d}";
}
