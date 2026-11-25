glob:priv ACTIONS: dict[str, str] = {
    "change-id": "_openspec_complete_changes",
    "spec-id": "_openspec_complete_specs",
    "change-or-spec-id": "_openspec_complete_items",
    "schema-name": "_openspec_complete_schemas",
    "path": "_files",
    "shell": "(zsh bash fish powershell)",
};

def:priv esc(description: str) -> str {
    return description.replace("\\", "\\\\").replace("'", "'\\''").replace("[", "\\[").replace(
        "]", "\\]"
    ).replace(":", "\\:");
}

def:priv fn(name: str) -> str {
    return name.replace("-", "_");
}

def:priv flagSpec(flag: any) -> str {
    (s, n) = (flag["short"], flag.name);
    head = f"'(-{s} --{n})'{{-{s},--{n}}}'" if s else f"'--{n}";
    value = "";
    if flag["takesValue"] {
        value = ":value:("
            + " ".join([
                v.replace("\\", "\\\\").replace("'", "\\'").replace(" ", "\\ ")
                for v in flag.values
            ])
            + ")"
            if flag["values"]
            else ":value:";
    }
    return f"{head}[{esc(flag.description)}]{value}'";
}

def:priv positionalSpecs(cmd: any) -> list[str] {
    if cmd["positionals"] {
        return [
            f"'{n + 1}"
                + ("::" if p["optional"] else ":")
                + esc(p.name)
                + ":"
                + ACTIONS.get(p["type"], "")
                + "'"
            for (n, p) in enumerate(cmd.positionals)
        ];
    }
    if not cmd["acceptsPositional"] {
        return [];
    }
    kind = cmd["positionalType"];
    return [
        "'*:"
            + (kind if kind in ["path", "shell"] else " ")
            + ":"
            + ACTIONS.get(kind, "_default")
            + "'",
    ];
}

def:priv continued(head: str, cmd: any, tail: list[str]) -> list[str] {
    lines = [head] + ["    " + flagSpec(f) for f in cmd.flags] + ["    " + s for s in tail];
    return [l + " \\" for l in lines[:-1]] + [lines[-1]];
}

def:priv commandFunction(cmd: any) -> list[str] {
    name = "_openspec_" + fn(cmd.name);
    subs = cmd["subcommands"] or [];
    if not subs {
        lines = [f"{name}() {{", *continued("  _arguments", cmd, positionalSpecs(cmd)), "}"];
    } else {
        lines = [
            f"{name}() {{",
            "  local context state line",
            "  typeset -A opt_args",
            "",
            "  local -a subcommands",
            "  subcommands=(",
        ]
            + [f"    '{s.name}:{esc(s.description)}'" for s in subs]
            + [
                "  )",
                "",
                *continued("  _arguments -C", cmd, ['"1: :->subcommand"', '"*::arg:->args"']),
            ]
            + [
                "",
                "  case $state in",
                "    subcommand)",
                '      _describe "subcommand" subcommands',
                "      ;;",
                "    args)",
                "      case $words[1] in",
            ]
            + [
                l
                for s in subs
                for l in [f"        {s.name})", f"          {name}_{fn(s.name)}", "          ;;"]
            ]
            + ["      esac", "      ;;", "  esac", "}"];
    }
    for s in subs {
        lines += [
            "",
            f"{name}_{fn(s.name)}() {{",
            *continued("  _arguments", s, positionalSpecs(s)),
            "}",
        ];
    }
    return lines;
}

obj ZshGenerator(globalThis.Object) {
    def init {
        super.init();
        self.shell = "zsh";
    }

    def generate(commands: any) -> str {
        commandList = "\n".join([f"    '{c.name}:{esc(c.description)}'" for c in commands]);
        cases = "\n".join([
            l
            for c in commands
            for l in [f"        {c.name})", f"          _openspec_{fn(c.name)}", "          ;;"]
        ]);
        functions = "\n".join([l for c in commands for l in [*commandFunction(c), ""]]);
        return f"""#compdef openspec

# Zsh completion script for OpenSpec CLI
# Auto-generated - do not edit manually

_openspec() {{
  local context state line
  typeset -A opt_args

  local -a commands
  commands=(
{commandList}
  )

  _arguments -C \\
    "1: :->command" \\
    "*::arg:->args"

  case $state in
    command)
      _describe "openspec command" commands
      ;;
    args)
      case $words[1] in
{cases}
      esac
      ;;
  esac
}}

{functions}
{ZSH_DYNAMIC_HELPERS}
compdef _openspec openspec
""";
    }
}
