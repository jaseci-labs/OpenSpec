import from "node:child_process" { execFileSync }
import from "node:process" { default as process }

type SupportedShell = any;

def:priv matchSupportedShell(name: any) -> any {
    executable = sub(name.trim().toLowerCase().split("/")[-1], "^-", "", "");
    return executable if executable in ["zsh", "bash", "fish"] else None;
}

def:priv detectShellFromParentProcess -> any {
    ppid = process.ppid;
    if process.platform == "win32" or not ppid or ppid <= 1 {
        return None;
    }
    try {
        return matchSupportedShell(
            execFileSync(
                "ps",
                ["-p", globalThis.String(ppid), "-o", "comm="],
                rec(encoding="utf8", timeout=1000),
            ),
        );
    } except Exception {
        return None;
    }
}

def:priv normalize(folder: any) -> str {
    return sub(folder.trim().toLowerCase().replace("/", "\\"), "\\\\+$", "", "");
}

def:priv isInsidePowerShellOnWindows -> bool {
    env = process.env;
    programFiles = [
        normalize(d) + "\\"
        for d in [env["ProgramFiles"], env["ProgramFiles(x86)"], env["ProgramW6432"]]
        if d
    ];
    return any([
        found(d, "\\\\(windows)?powershell\\\\modules$")
            and not any([d.startswith(p) for p in programFiles])
        for d in [normalize(e) for e in (env["PSModulePath"] ?? "").split(";")]
    ]);
}

def detectShell -> any {
    env = process.env;
    shellPath: any = env["SHELL"];
    supported = detectShellFromParentProcess()
        or (matchSupportedShell(shellPath) if shellPath else None);
    if supported {
        return rec(shell=supported, detected=supported);
    }
    if shellPath {
        m = matchOf(shellPath, "/([^/]+)$");
        return rec(shell=None, detected=m[1] if m else shellPath);
    }
    win = process.platform == "win32";
    if (isInsidePowerShellOnWindows() if win else truthy(env["PSModulePath"])) {
        return rec(shell="powershell", detected="powershell");
    }
    cmd = win and "cmd.exe" in (env["COMSPEC"] ?? "").toLowerCase();
    return rec(shell=None, detected="cmd.exe" if cmd else None);
}
