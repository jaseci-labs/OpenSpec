glob:priv POSITIONAL: dict[str, str] = {
    "change-id": "-a '(__fish_openspec_changes)' -f",
    "spec-id": "-a '(__fish_openspec_specs)' -f",
    "change-or-spec-id": "-a '(__fish_openspec_items)' -f",
    "schema-name": "-a '(__fish_openspec_schemas)' -f",
    "shell": "-a 'zsh bash fish powershell' -f",
    "path": "-F",
};

def:priv esc(description: str) -> str {
    return description.replace("\\", "\\\\").replace("'", "\\'");
}

def:priv positional(kind: any, cond: str) -> str {
    return f"complete -c openspec -n '{cond}' " + POSITIONAL.get(kind, "-f");
}

def:priv valueFlags(flags: any) -> list[str] {
    names: list[str] = [];
    for f in flags {
        for n in ([f"--{f.name}"] + ([f"-{f.short}"] if f["short"] else []))
            if f["takesValue"]
            else [] {
            if n not in names {
                names.append(n);
            }
        }
    }
    return names;
}

def:priv pathCond(words: list[str], flags: list[str] = []) -> str {
    return "__fish_openspec_using_command_path "
        + " ".join(words)
        + (" -- " + " ".join(flags) if flags else "");
}

def:priv flagCompletion(flag: any, cond: str) -> list[str] {
    d = esc(flag.description);
    opts = (f"-s {flag.short} " if flag["short"] else "") + f"-l {flag.name}";
    head = f"complete -c openspec -n '{cond}' {opts}";
    if not flag["takesValue"] {
        return [f"{head} -f -d '{d}'"];
    }
    if truthy(flag["values"]) {
        return [f"{head} -r -f -a '{v}' -d '{d}'" for v in flag.values];
    }
    lines = [f"{head} -r -f -d '{d}'"];
    if flag["completionType"] == "path" {
        names = " ".join(valueFlags([flag]));
        lines.append(
            f"complete -c openspec -n '{cond}; and __fish_openspec_completing_option_value {names}' {opts} -r -F -d '{d}'",
        );
        if flag["short"] {
            lines.append(
                f"{head} -r -f -a '(__fish_openspec_complete_attached_short_path -{flag.short})' -d '{d}'",
            );
        }
    }
    return lines;
}

def:priv section(title: str, cond: str, cmd: any, flags: list[str], depth: int) -> list[str] {
    lines = [f"# {title} flags", f"complete -c openspec -n '{cond}' -f"] + [
        l
        for f in cmd.flags
        for l in flagCompletion(f, cond)
    ];
    if cmd["positionals"] {
        suffix = " " + " ".join(flags) if flags else "";
        return lines + [
            positional(
                p["type"], f"{cond}; and __fish_openspec_positional_index {n} {depth}{suffix}"
            )
            for (n, p) in enumerate(cmd.positionals)
        ];
    }
    return lines + ([positional(cmd["positionalType"], cond)] if cmd["acceptsPositional"] else []);
}

def:priv commandCompletions(cmd: any) -> list[str] {
    subs = cmd["subcommands"];
    cond = pathCond([cmd.name]);
    if not subs {
        return section(cmd.name, cond, cmd, valueFlags(cmd.flags), 1);
    }
    parent = valueFlags(cmd.flags);
    none = "; and ".join([f"not {pathCond([cmd.name, s.name], parent)}" for s in subs]);
    lines = [
        f"complete -c openspec -n '{cond}; and {none}' -f -a '{s.name}' -d '{esc(s.description)}'"
        for s in subs
    ]
        + [""]
        + [l for f in cmd.flags for l in flagCompletion(f, cond)];
    for s in subs {
        lines += section(
            f"{cmd.name} {s.name}",
            pathCond([cmd.name, s.name], parent),
            s,
            valueFlags([*cmd.flags, *s.flags]),
            2,
        );
    }
    return lines;
}

obj FishGenerator(globalThis.Object) {
    def init {
        super.init();
        self.shell = "fish";
    }

    def generate(commands: any) -> str {
        top = "\n".join([
            l
            for c in commands
            for l in [
                f"# {c.name} command",
                f"complete -c openspec -n '__fish_openspec_no_subcommand' -f -a '{c.name}' -d '{esc(c.description)}'",
            ]
        ]);
        completions = "\n".join([l for c in commands for l in [*commandCompletions(c), ""]]);
        return f"""# Fish completion script for OpenSpec CLI
# Auto-generated - do not edit manually

{FISH_STATIC_HELPERS}
{FISH_DYNAMIC_HELPERS}
complete -c openspec -l no-color -f -d 'Disable color output'
{top}

{completions}""";
    }
}
