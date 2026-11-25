import from "@inquirer/core" {
    createPrompt,
    useState,
    useKeypress,
    usePrefix,
    isEnterKey,
    isBackspaceKey,
    isUpKey,
    isDownKey,
}
import from "chalk" { default as chalk }

def:priv isPrintable(text: any) -> bool {
    return kind(text) == "string"
        and len(text) > 0
        and all([ch >= " " and ch != "\u007f" for ch in text]);
}

def:priv render(config: any, done: any) -> str {
    choices: any = config.choices;
    pageSize: int = config["pageSize"] ?? 15;
    validate: any = config["validate"];
    (searchText, setSearchText) = useState("");
    (selected, setSelected) = useState(
        lambda -> any { [c.value for c in choices if c["preSelected"]] }
    );
    (cursor, setCursor) = useState(0);
    (status, setStatus) = useState("idle");
    (error, setError) = useState(JsNull);
    prefix = usePrefix(rec(status=status));
    term: any = searchText.trim().toLowerCase();
    shown: any = [
        c
        for c in choices
        if any([
            t.toLowerCase().includes(term)
            for t in [c.name, c.value, *(c["searchAliases"] or [])]
        ])
    ]
        if term
        else choices;
    names = {c.value: c.name for c in choices};

    def onKey(key: any) {
        if status == "done" {
            return;
        }
        if isEnterKey(key) {
            result: any = True if missing(validate) else validate(selected);
            if not same(result, True) {
                setError(result if kind(result) == "string" else "Invalid");
                return;
            }
            setStatus("done");
            done(selected);
        } elif key["name"] == "space" {
            if 0 <= cursor < len(shown) {
                value = shown[cursor].value;
                setSelected(
                    [v for v in selected if v != value] if value in selected else [*selected, value]
                );
            }
        } elif isBackspaceKey(key) {
            if searchText == "" and len(selected) > 0 {
                setSelected(selected[:-1]);
            } else {
                setSearchText(searchText[:-1]);
                setCursor(0);
            }
        } elif isUpKey(key) {
            setCursor(max(0, cursor - 1));
        } elif isDownKey(key) {
            setCursor(min(len(shown) - 1, cursor + 1));
        } elif not (key["ctrl"] or key["meta"]) {
            name: any = key["name"];
            typed: any = key["sequence"]
                if isPrintable(key["sequence"])
                else name if isPrintable(name) and len(name) == 1 else None;
            if typed {
                setSearchText(searchText + typed);
                setCursor(0);
            }
        }
    }
    useKeypress(onKey);
    head = f"{prefix} {chalk.bold(config.message)}";
    if status == "done" {
        return f"{head} {chalk.cyan(', '.join([names.get(v) ?? v for v in selected]) or '(none)')}";
    }
    chips = " ".join([chalk.bgCyan.black(f" {names.get(v)} ") for v in selected])
        or chalk.dim("(none selected)");
    lines = [
        head,
        f"  Selected: {chips}",
        f"  Search: {chalk.yellow('[')}{searchText or chalk.dim('type to filter')}{chalk.yellow(']')}",
        f"  {chalk.cyan('↑↓')} navigate • {chalk.cyan('Space')} toggle • {chalk.cyan('Backspace')} remove • {chalk.cyan('Enter')} confirm",
    ];
    total = len(shown);
    if total == 0 {
        lines.append(chalk.yellow("  No matches"));
        if config["emptyHint"] {
            lines.append(chalk.dim(f"  {config['emptyHint']}"));
        }
    } else {
        start = max(0, min(cursor - pageSize // 2, total - pageSize));
        for (i, item) in enumerate(shown[start:min(start + pageSize, total)], start) {
            picked = item.value in selected;
            icon = chalk.green("[x]") if picked else chalk.dim("[ ]");
            arrow = chalk.cyan("›") if i == cursor else " ";
            name = chalk.cyan(item.name) if i == cursor else item.name;
            label = (" (refresh)" if item["configured"] else " (selected)")
                if picked
                else " (configured)"
                    if item["configured"]
                    else " (detected)" if item["detected"] else "";
            lines.append(f"  {arrow} {icon} {name}{chalk.dim(label)}");
        }
        if total > pageSize {
            lines.append(
                chalk.dim(f"  ({cursor // pageSize + 1}/{(total + pageSize - 1) // pageSize})")
            );
        }
    }
    if error {
        lines.append(chalk.red(f"  {error}"));
    }
    return "\n".join(lines);
}

async def searchableMultiSelect(config: any) -> any {
    return await createPrompt(render)(config);
}

default glob prompt: any = searchableMultiSelect;
