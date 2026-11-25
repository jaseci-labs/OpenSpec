import from "node:fs" { statSync, accessSync, constants }
import from "node:path" { posix, win32, isAbsolute }
import from "node:os" { platform as hostPlatform }
import from "node:process" { default as process }
import from "zod" { z }

type OpenerDefinition = any;
type OpenerScanOptions = any;
type OpenerChoice = any;
type LaunchCommand = any;

glob:priv DEFAULT_ATTACH_FLAG: str = "--add-dir";

glob BUILTIN_OPENERS: any = [
    rec(id=id, label=label, style=style, command=id, args=args, attachFlag=DEFAULT_ATTACH_FLAG)
    for (id, label, style, args) in [
        ("code", "VS Code", "workspace-file", []),
        ("cursor", "Cursor", "workspace-file", []),
        ("claude", "Claude Code", "attach-dirs", []),
        ("codex", "codex", "attach-dirs", ["--sandbox", "workspace-write"]),
    ]
];

glob:priv OpenersConfigSchema: any = z.record(
    z.string(),
    z.object(
        rec(
            style=z.enum(["workspace-file", "attach-dirs"]).optional(),
            label=z.string().min(1).optional(),
            command=z.string().min(1).optional(),
            args=z.array(z.string()).optional(),
            attach_flag=z.string().min(1).optional(),
        ),
    ).strict(),
);

def isCliAgentOpenersEnabled -> bool {
    return process.env["OPENSPEC_ENABLE_CLI_AGENT_OPENERS"] == "1";
}

def isOpenerEnabled(opener: any) -> bool {
    return isCliAgentOpenersEnabled() or opener.style != "attach-dirs";
}

def:priv invalidConfig(message: str, configPath: str) -> StoreError {
    return StoreError(
        f"Invalid openers config: {message}",
        "invalid_opener_config",
        rec(
            target="openers.config",
            fix=f"Each entry under \"openers\" in {configPath} may set style ('workspace-file' or 'attach-dirs'), label, command, args, and attach_flag; new tools must set style.",
        ),
    );
}

def mergeOpenerTable(rawOpeners: any, configPath: str) -> list[any] {
    table = [merge(o, rec(args=[*o.args])) for o in BUILTIN_OPENERS];
    if missing(rawOpeners) {
        return table;
    }
    result = OpenersConfigSchema.safeParse(rawOpeners);
    if not result.success {
        raise invalidConfig(formatZodIssues(result.error, "openers"), configPath);
    }
    for (id, row) in globalThis.Object.entries(result.data) {
        opener = findOpener(table, id);
        if opener is JsNull {
            if row["style"] is None {
                raise invalidConfig(
                    f"'{id}' adds a new tool and must set style ('workspace-file' or 'attach-dirs')",
                    configPath,
                );
            }
            opener = rec(
                id=id,
                label=id,
                style=row.style,
                command=id,
                args=[],
                attachFlag=DEFAULT_ATTACH_FLAG,
            );
            table.append(opener);
        }
        for (key, value) in globalThis.Object.entries(row) {
            if value is not None {
                opener["attachFlag" if key == "attach_flag" else key] = value;
            }
        }
    }
    return table;
}

def:priv isExecutableFile(candidate: str, platform: str) -> bool {
    try {
        if not statSync(candidate).isFile() {
            return False;
        }
        if platform != "win32" {
            accessSync(candidate, constants.X_OK);
        }
        return True;
    } except Exception {
        return False;
    }
}

def isOpenerCommandAvailable(command: str, options: any = None) -> bool {
    env = at(options, "env") ?? process.env;
    platform: str = at(options, "platform") ?? hostPlatform();
    paths = win32 if platform == "win32" else posix;
    check = at(options, "isExecutableFile")
        ?? (lambda (candidate: str) -> bool { isExecutableFile(candidate, platform) });
    suffixes: list[str] = [""];
    if platform == "win32" {
        suffixes = [
            e.strip()
            for e in (env["PATHEXT"] ?? ".COM;.EXE;.BAT;.CMD").split(";")
            if e.strip()
        ];
        if [e for e in suffixes if command.lower().endswith(e.lower())] {
            suffixes = [""];
        }
    }
    candidates = [command + s for s in globalThis.Array.from(new(globalThis.Set, ["", *suffixes]))]
        if found(command, "[\\\\/]")
        else [
            paths.join(directory, command + s)
            for directory in (env["PATH"] ?? env["Path"] ?? env["path"] ?? "").split(
                paths.delimiter
            )
            if directory
            for s in suffixes
        ];
    for candidate in candidates {
        if check(candidate) {
            return True;
        }
    }
    return False;
}

def listOpenerChoices(table: list[any], options: any = None) -> list[any] {
    choices = [
        rec(
            opener=o,
            available=available,
            note=JsNull if available else f"({o.command} not found on PATH)",
        )
        for o in table
        if isOpenerEnabled(o)
        for available in [isOpenerCommandAvailable(o.command, options)]
    ];
    return sorted(choices, key=lambda (c: any) -> int { 0 if c.available else 1 });
}

def findOpener(table: any, id: str) -> any {
    return table.find(lambda (o: any) -> bool { o.id == id }) ?? JsNull;
}

def buildLaunchCommand(opener: any, request: any) -> any {
    if not len(request.members) {
        raise new(globalThis.Error, "buildLaunchCommand requires at least one member.");
    }
    if not isAbsolute(request.codeWorkspacePath) {
        raise new(
            globalThis.Error,
            f"buildLaunchCommand requires an absolute workspace-file path (got '{request.codeWorkspacePath}').",
        );
    }
    tail = [request.codeWorkspacePath]
        if opener.style == "workspace-file"
        else [arg for m in request.members for arg in [opener.attachFlag, m.path]];
    return rec(
        executable=opener.command,
        args=[*opener.args, *tail],
        cwd=request.members[0].path,
        label=opener.label,
        style=opener.style,
    );
}
