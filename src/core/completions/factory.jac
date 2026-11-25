import from "node:fs" { promises as fs }
import from "node:path" { dirname }
import from "node:process" { default as process }

type InstallationResult = any;

type CompletionInstaller = any;

glob:priv SHELLS: list[str] = ["zsh", "bash", "fish", "powershell"];

glob START_MARKER: str = "# OPENSPEC:START",
     END_MARKER: str = "# OPENSPEC:END",
     UP_TO_DATE: str = "Completion script is already installed (up to date)";

def errorText(e: any) -> str {
    err = js_error(e);
    return err.message if isinstance(err, globalThis.Error) else globalThis.String(err);
}

def debugText(e: any) -> str {
    return globalThis.String(at(js_error(e), "message"));
}

def failed(verb: str, e: any, extra: any = None) -> any {
    return merge(
        rec(success=False),
        extra,
        rec(message=f"Failed to {verb} completion script: {errorText(e)}"),
    );
}

async def ensureWritable(target: str) {
    if not await FileSystemUtils.canWriteFile(target) {
        raise new(globalThis.Error, f"Path is not writable: {target}");
    }
}

async def backupFile(targetPath: str) -> any {
    try {
        await fs.access(targetPath);
        backupPath = f"{targetPath}.backup-" + sub(new(globalThis.Date).toISOString(), "[:.]", "-");
        await fs.copyFile(targetPath, backupPath);
        return backupPath;
    } except Exception {
        return None;
    }
}

async def isScriptFile(targetPath: str) -> bool {
    try {
        return (await fs.stat(targetPath)).isFile();
    } except Exception {
        return False;
    }
}

async def placeScript(installer: any, targetPath: str, script: str) -> any {
    isUpdate = False;
    try {
        if (await fs.readFile(targetPath, "utf-8")) == script {
            return None;
        }
        isUpdate = True;
    } except Exception as e {
        globalThis.console.debug(
            f"Unable to read existing completion file at {targetPath}: {debugText(e)}"
        );
    }
    await ensureWritable(targetPath);
    await fs.mkdir(dirname(targetPath), rec(recursive=True));
    backupPath = (await installer.backupExistingFile(targetPath)) if isUpdate else None;
    await fs.writeFile(targetPath, script, "utf-8");
    if not isUpdate {
        return (None, None);
    }
    return (
        "Completion script updated successfully"
            + (" (previous version backed up)" if backupPath else ""),
        backupPath,
    );
}

async def uninstallScript(targetPath: str, checkDir: bool, cleanup: any = None) -> any {
    try {
        try {
            await fs.access(targetPath);
        } except Exception {
            return rec(success=False, message="Completion script is not installed");
        }
        if checkDir {
            await ensureWritable(dirname(targetPath));
        }
        await fs.unlink(targetPath);
        if cleanup {
            await cleanup();
        }
        return rec(success=True, message="Completion script uninstalled successfully");
    } except Exception as e {
        return failed("uninstall", e);
    }
}

async def configureRc(rcPath: str, config: str, label: str) -> bool {
    if process.env.OPENSPEC_NO_AUTO_CONFIG == "1" {
        return False;
    }
    try {
        if not await FileSystemUtils.canWriteFile(rcPath) {
            return False;
        }
        await FileSystemUtils.updateFileWithMarkers(rcPath, config, START_MARKER, END_MARKER);
        return True;
    } except Exception as e {
        globalThis.console.debug(f"Unable to configure {label} for completions: {debugText(e)}");
        return False;
    }
}

async def removeRcBlock(rcPath: str, label: str) -> bool {
    try {
        try {
            await fs.access(rcPath);
        } except Exception {
            return True;
        }
        content: str = await fs.readFile(rcPath, "utf-8");
        if START_MARKER not in content or END_MARKER not in content {
            return True;
        }
        lines: list[any] = content.split("\n");
        trimmed = [line.trim() for line in lines];
        start = trimmed.index(START_MARKER) if START_MARKER in trimmed else -1;
        end = trimmed.index(END_MARKER) if END_MARKER in trimmed else -1;
        if start == -1 or end == -1 or end < start {
            return False;
        }
        lines = lines[:start] + lines[end + 1:];
        if start == 0 and lines and lines[0].trim() == "" {
            lines = lines[1:];
        }
        await fs.writeFile(rcPath, "\n".join(lines), "utf-8");
        return True;
    } except Exception as e {
        globalThis.console.debug(f"Unable to remove {label} configuration: {debugText(e)}");
        return False;
    }
}

def:priv choose(table: any, shell: any) -> any {
    if shell not in SHELLS {
        raise new(globalThis.Error, f"Unsupported shell: {globalThis.String(shell)}");
    }
    return new(table[SHELLS.index(shell)]);
}

obj CompletionFactory(globalThis.Object) {
    static def createGenerator(shell: any) -> any {
        return choose([ZshGenerator, BashGenerator, FishGenerator, PowerShellGenerator], shell);
    }

    static def createInstaller(shell: any) -> any {
        return choose([ZshInstaller, BashInstaller, FishInstaller, PowerShellInstaller], shell);
    }

    static def isSupported(shell: any) -> bool {
        return shell in SHELLS;
    }

    static def getSupportedShells -> list[str] {
        return list(SHELLS);
    }
}
