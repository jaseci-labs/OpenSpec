glob:priv POSITIONAL: dict[str, list[str]] = {
    "change-id": ["_openspec_complete_changes"],
    "spec-id": ["_openspec_complete_specs"],
    "change-or-spec-id": ["_openspec_complete_items"],
    "schema-name": ["_openspec_complete_schemas"],
    "shell": [
        'local shells="zsh bash fish powershell"',
        'COMPREPLY=($(compgen -W "$shells" -- "$cur"))',
    ],
    "path": ['COMPREPLY=($(compgen -f -- "$cur"))'],
};

def:priv esc(name: str) -> str {
    return sub(name, "[\"$`\\\\]", "\\$&");
}

def:priv positional(kind: any, i: str) -> list[str] {
    return [i + line for line in POSITIONAL.get(kind, [])];
}

def:priv valueFlags(flags: any) -> list[str] {
    return [
        n
        for f in flags
        if f["takesValue"]
        for n in [f"--{f.name}"] + ([f"-{f.short}"] if f["short"] else [])
    ];
}

def:priv offer(i: str, cond: str, var: str, words: str) -> list[str] {
    return [
        f"{i}if [[ {cond} ]]; then",
        f'{i}  local {var}="{words}"',
        f'{i}  COMPREPLY=($(compgen -W "${var}" -- "$cur"))',
        f"{i}  return 0",
        f"{i}fi",
        "",
    ];
}

def:priv flagOffer(flags: any, i: str) -> list[str] {
    words = " ".join([(f"-{f.short} " if f["short"] else "") + f"--{f.name}" for f in flags]);
    return offer(i, '"$cur" == -*', "flags", words) if flags else [];
}

def:priv indexed(positionals: any, flags: any, first: int, i: str) -> list[str] {
    cases = valueFlags(flags);
    alt = "|".join(cases);
    lines = [f'{i}case "$prev" in', f"{i}  {alt}) return 0 ;;", f"{i}esac", ""] if cases else [];
    lines += [
        f"{i}local positional_index=0",
        f"{i}local skip_next=0",
        f"{i}local i",
        f"{i}for ((i = {first}; i < cword; i++)); do",
        f"{i}  if [[ $skip_next -eq 1 ]]; then",
        f"{i}    skip_next=0",
        f"{i}    continue",
        f"{i}  fi",
        f'{i}  case "${{words[i]}}" in',
    ];
    if cases {
        lines += [
            f"{i}    {alt}) skip_next=1 ;;",
            f"{i}    " + "|".join([c + "=*" for c in cases]) + ") ;;",
        ];
    }
    lines += [
        f"{i}    -*) ;;",
        f"{i}    *) ((positional_index++)) ;;",
        f"{i}  esac",
        f"{i}done",
        "",
        f'{i}case "$positional_index" in',
    ];
    for (n, p) in enumerate(positionals) {
        body = positional(p["type"], i + "  ");
        if body {
            lines += [f"{i}  {n})", *body, f"{i}    ;;"];
        }
    }
    return lines + [f"{i}esac"];
}

def:priv argument(cmd: any, i: str, first: int) -> list[str] {
    if cmd["positionals"] {
        return flagOffer(cmd.flags, i) + indexed(cmd.positionals, cmd.flags, first, i);
    }
    return flagOffer(cmd.flags, i)
        + (positional(cmd["positionalType"], i) if cmd["acceptsPositional"] else []);
}

def:priv commandCase(cmd: any, i: str) -> list[str] {
    subs = cmd["subcommands"];
    if not subs {
        return argument(cmd, i, 2);
    }
    lines = flagOffer(cmd.flags, i)
        + offer(i, "$cword -eq 2", "subcommands", " ".join([esc(s.name) for s in subs]))
        + [f'{i}case "$subcmd" in'];
    for s in subs {
        lines += [f"{i}  {s.name})", *argument(s, i + "    ", 3), f"{i}    ;;"];
    }
    return lines + [f"{i}esac"];
}

obj BashGenerator(globalThis.Object) {
    def init {
        super.init();
        self.shell = "bash";
    }

    def generate(commands: any) -> str {
        commandList = " ".join([esc(c.name) for c in commands]);
        cases = "\n".join([
            l
            for c in commands
            for l in [f"    {c.name})", *commandCase(c, "      "), "      ;;"]
        ]);
        return f"""# Bash completion script for OpenSpec CLI
# Auto-generated - do not edit manually

_openspec_completion() {{
  local cur prev words cword

  # Use _init_completion if available (from bash-completion package)
  # The -n : option prevents colons from being treated as word separators
  # (important for spec/change IDs that may contain colons)
  # Otherwise, fall back to manual initialization
  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -n : || return
  else
    # Manual fallback when bash-completion is not installed
    COMPREPLY=()
    cur="${{COMP_WORDS[COMP_CWORD]}}"
    prev="${{COMP_WORDS[COMP_CWORD-1]}}"
    words=("${{COMP_WORDS[@]}}")
    cword=$COMP_CWORD
  fi

  local cmd="${{words[1]}}"
  local subcmd="${{words[2]}}"

  # Top-level commands
  if [[ $cword -eq 1 ]]; then
    local commands="{commandList}"
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    return 0
  fi

  # Command-specific completion
  case "$cmd" in
{cases}
  esac

  return 0
}}

{BASH_DYNAMIC_HELPERS}
complete -F _openspec_completion openspec
""";
    }
}
