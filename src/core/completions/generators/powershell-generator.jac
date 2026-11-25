glob:priv RESULT: str = "[System.Management.Automation.CompletionResult]::new";

def:priv choices(source: str, label: str, first: list[str] = []) -> list[str] {
    return first + [
        f'{source} | Where-Object {{ $_ -like "$wordToComplete*" }} | ForEach-Object {{',
        f'    {RESULT}($_, $_, "ParameterValue", {label})',
        "}",
    ];
}

glob:priv POSITIONAL: dict[str, list[str]] = {
    "change-id": choices("Get-OpenSpecChanges", '"Change: $_"'),
    "spec-id": choices("Get-OpenSpecSpecs", '"Spec: $_"'),
    "change-or-spec-id": choices(
        "$items", "$_", ["$items = @(Get-OpenSpecChanges) + @(Get-OpenSpecSpecs)"]
    ),
    "schema-name": choices("Get-OpenSpecSchemas", '"Schema: $_"'),
    "shell": choices(
        "$shells", '"Shell: $_"', ['$shells = @("zsh", "bash", "fish", "powershell")']
    ),
};

def:priv esc(description: str) -> str {
    return description.replace("`", "``").replace("$", "`$").replace('"', '""');
}

def:priv positional(kind: any, i: str) -> list[str] {
    return [i + line for line in POSITIONAL.get(kind, [])];
}

def:priv table(i: str, rows: list[any]) -> list[str] {
    lines = [f'{i}@{{Name="{name}"; Description="{esc(d)}"}},' for (name, d) in rows];
    if lines {
        lines[-1] = lines[-1][:-1];
    }
    return lines;
}

def:priv offer(i: str, cond: str, var: str, rows: list[any], kind: str) -> list[str] {
    return [
        f"{i}if ({cond}) {{",
        f"{i}    ${var} = @(",
        *table(i + "        ", rows),
        f"{i}    )",
    ] + [
        f'{i}    ${var} | Where-Object {{ $_.Name -like "$wordToComplete*" }} | ForEach-Object {{',
        f'{i}        {RESULT}($_.Name, $_.Name, "{kind}", $_.Description)',
        f"{i}    }}",
        f"{i}    return",
        f"{i}}}",
        "",
    ];
}

def:priv flagOffer(flags: any, i: str) -> list[str] {
    rows = [
        (n, f.description)
        for f in flags
        for n in [f"--{f.name}"] + ([f"-{f.short}"] if f["short"] else [])
    ];
    return offer(i, '$wordToComplete -like "-*"', "flags", rows, "ParameterName") if rows else [];
}

def:priv indexed(positionals: any, flags: any, first: int, i: str) -> list[str] {
    cases: list[str] = [];
    for (n, p) in enumerate(positionals) {
        body = positional(p["type"], i + "    ");
        if body {
            cases += [f"{i}    {n} {{", *body, f"{i}    }}"];
        }
    }
    if not cases {
        return [];
    }
    names = [
        n
        for f in flags
        if f["takesValue"]
        for n in [f"--{f.name}"] + ([f"-{f.short}"] if f["short"] else [])
    ];
    quoted = ", ".join([f'"{n}"' for n in names]);
    lines = [f"{i}if (@({quoted}) -contains $tokens[$commandCount - 2]) {{ return }}", ""]
        if names
        else [];
    lines += [
        f"{i}$positionalIndex = 0",
        f"{i}$skipNext = $false",
        f"{i}for ($i = {first}; $i -lt ($commandCount - 1); $i++) {{",
        f"{i}    if ($skipNext) {{",
        f"{i}        $skipNext = $false",
        f"{i}        continue",
        f"{i}    }}",
        f"{i}    $token = $tokens[$i]",
    ];
    if names {
        alt = "|".join([sub(n, "[.*+?^${}()|[\\]\\\\]", "\\$&") for n in names]);
        lines += [
            f"{i}    if (@({quoted}) -contains $token) {{",
            f"{i}        $skipNext = $true",
            f"{i}        continue",
            f"{i}    }}",
            f'{i}    if ($token -match "^({alt})=.*") {{ continue }}',
        ];
    }
    return lines + [
        f'{i}    if ($token -like "-*") {{ continue }}',
        f"{i}    $positionalIndex++",
        f"{i}}}",
        "",
        f"{i}switch ($positionalIndex) {{",
        *cases,
        f"{i}}}",
    ];
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
        + offer(
            i,
            "$commandCount -eq 2 -or ($commandCount -eq 3 -and $wordToComplete)",
            "subcommands",
            [(s.name, s.description) for s in subs],
            "ParameterValue",
        )
        + [
            f'{i}$subcommand = if ($commandCount -gt 2) {{ $tokens[2] }} else {{ "" }}',
            f"{i}switch ($subcommand) {{",
        ];
    for s in subs {
        lines += [f'{i}    "{s.name}" {{', *argument(s, i + "        ", 3), f"{i}    }}"];
    }
    return lines + [f"{i}}}"];
}

obj PowerShellGenerator(globalThis.Object) {
    def init {
        super.init();
        self.shell = "powershell";
    }

    def generate(commands: any) -> str {
        top = "\n".join(table("            ", [(c.name, c.description) for c in commands]));
        cases = "\n".join([
            l
            for c in commands
            for l in [f'        "{c.name}" {{', *commandCase(c, "            "), "        }"]
        ]);
        return f"""# PowerShell completion script for OpenSpec CLI
# Auto-generated - do not edit manually

{POWERSHELL_DYNAMIC_HELPERS}
$openspecCompleter = {{
    param($wordToComplete, $commandAst, $cursorPosition)

    $tokens = $commandAst.ToString() -split "\\s+"
    $commandCount = ($tokens | Measure-Object).Count

    # Top-level commands
    if ($commandCount -eq 1 -or ($commandCount -eq 2 -and $wordToComplete)) {{
        $commands = @(
{top}
        )
        $commands | Where-Object {{ $_.Name -like "$wordToComplete*" }} | ForEach-Object {{
            [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, "ParameterValue", $_.Description)
        }}
        return
    }}

    $command = $tokens[1]

    switch ($command) {{
{cases}
    }}
}}

Register-ArgumentCompleter -CommandName openspec -ScriptBlock $openspecCompleter
""";
    }
}
