import from "node:fs" { promises as fs }
import from "node:path" { join, dirname }
import from "node:os" { homedir }
import from "node:process" { default as process }

glob:priv PROFILE_FILE: str = "Microsoft.PowerShell_profile.ps1";

async def:priv readProfile(filePath: str) -> any {
    raw = await fs.readFile(filePath);
    head: str = raw.subarray(0, 3).toString("hex");
    if head.startswith("feff") {
        raise new(
            globalThis.Error,
            "File is encoded as UTF-16 BE which is not supported. Please re-save as UTF-8 or UTF-16 LE, then retry.",
        );
    }
    (encoding, size) = ("utf16le", 2)
        if head.startswith("fffe")
        else ("utf-8", 3 if head == "efbbbf" else 0);
    return (raw.subarray(size).toString(encoding), encoding, raw.subarray(0, size));
}

async def:priv writeProfile(filePath: str, content: str, encoding: str, bom: any) {
    await fs.writeFile(
        filePath, globalThis.Buffer.concat([bom, globalThis.Buffer.from(content, encoding)])
    );
}

def:priv messageOf(e: any) -> any {
    err = js_error(e);
    return at(err, "message") ?? globalThis.String(err);
}

obj PowerShellInstaller(globalThis.Object) {
    def init(homeDir: any = None) {
        super.init();
        self.homeDir = homeDir ?? homedir();
    }

    def getProfilePath -> str {
        return self.profilePaths()[0];
    }

    def profilePaths -> list[str] {
        if process.env.PROFILE {
            return [process.env.PROFILE];
        }
        if process.platform == "win32" {
            return [
                join(self.homeDir, "Documents", "PowerShell", PROFILE_FILE),
                join(self.homeDir, "Documents", "WindowsPowerShell", PROFILE_FILE),
            ];
        }
        return [join(self.homeDir, ".config", "powershell", PROFILE_FILE)];
    }

    def getInstallationPath -> str {
        return join(dirname(self.getProfilePath()), "OpenSpecCompletion.ps1");
    }

    async def isInstalled -> bool {
        return await isScriptFile(self.getInstallationPath());
    }

    async def backupExistingFile(targetPath: str) -> any {
        return await backupFile(targetPath);
    }

    async def configureProfile(scriptPath: str) -> bool {
        anyConfigured = False;
        for profilePath in self.profilePaths() {
            try {
                try {
                    await fs.access(profilePath);
                } except Exception as e {
                    if at(js_error(e), "code") != "ENOENT" {
                        raise;
                    }
                    await ensureWritable(profilePath);
                    await fs.mkdir(dirname(profilePath), rec(recursive=True));
                }
                file: any = ("", "utf-8", globalThis.Buffer.alloc(0));
                try {
                    file = await readProfile(profilePath);
                } except Exception as e {
                    if at(js_error(e), "code") != "ENOENT" {
                        globalThis.console.warn(f"Warning: Skipping {profilePath}: {messageOf(e)}");
                        continue;
                    }
                }
                (content, encoding, bom) = file;
                scriptLine = f'. "{scriptPath}"';
                if scriptLine in content {
                    continue;
                }
                block = [
                    "",
                    "# OPENSPEC:START - OpenSpec completion (managed block, do not edit manually)",
                    scriptLine,
                    END_MARKER,
                    "",
                ];
                await ensureWritable(profilePath);
                await writeProfile(profilePath, content + "\n".join(block), encoding, bom);
                anyConfigured = True;
            } except Exception as e {
                globalThis.console.warn(
                    f"Warning: Could not configure {profilePath}: {globalThis.String(js_error(e))}"
                );
            }
        }
        return anyConfigured;
    }

    async def removeProfileConfig -> bool {
        anyRemoved = False;
        for profilePath in self.profilePaths() {
            try {
                file: any = None;
                try {
                    file = await readProfile(profilePath);
                } except Exception as e {
                    if at(js_error(e), "code") != "ENOENT" {
                        globalThis.console.warn(
                            f"Warning: Could not read {profilePath}: {messageOf(e)}"
                        );
                    }
                    continue;
                }
                (text, encoding, bom) = file;
                content: str = text;
                start = content.find(START_MARKER);
                if start == -1 {
                    continue;
                }
                end = content.find(END_MARKER, start);
                if end == -1 {
                    globalThis.console.warn(
                        f"Warning: Found start marker but no end marker in {profilePath}"
                    );
                    continue;
                }
                before: any = content[:start];
                after: any = content[end + len(END_MARKER):];
                joined: any = before.trimEnd() + "\n" + after.trimStart();
                await ensureWritable(profilePath);
                await writeProfile(profilePath, joined.trim() + "\n", encoding, bom);
                anyRemoved = True;
            } except Exception as e {
                globalThis.console.warn(
                    f"Warning: Could not clean {profilePath}: {globalThis.String(js_error(e))}"
                );
            }
        }
        return anyRemoved;
    }

    async def install(completionScript: str) -> any {
        try {
            targetPath = self.getInstallationPath();
            placed = await placeScript(self, targetPath, completionScript);
            if placed is None {
                return rec(
                    success=True,
                    installedPath=targetPath,
                    message=UP_TO_DATE,
                    instructions=[
                        "The completion script is already installed and up to date.",
                        "If completions are not working, try restarting PowerShell or run: . $PROFILE",
                    ],
                );
            }
            (updated, backupPath) = placed;
            configured = await self.configureProfile(targetPath);
            return rec(
                success=True,
                installedPath=targetPath,
                backupPath=backupPath,
                profileConfigured=configured,
                message=updated
                    or (
                        "Completion script installed and PowerShell profile configured successfully"
                            if configured
                            else "Completion script installed successfully for PowerShell"
                    ),
                instructions=None
                    if configured
                    else [
                        "Completion script installed successfully.",
                        "",
                        f"To enable completions, add the following to your PowerShell profile ({self.getProfilePath()}):",
                        "",
                        "  # Source OpenSpec completions",
                        f'  if (Test-Path "{targetPath}") {{',
                        f'      . "{targetPath}"',
                        "  }",
                        "",
                        "Then restart PowerShell or run: . $PROFILE",
                    ],
            );
        } except Exception as e {
            return failed("install", e);
        }
    }

    async def uninstall(options: any = None) -> any {
        return await uninstallScript(
            self.getInstallationPath(), True, lambda -> any { self.removeProfileConfig() }
        );
    }
}

with entry {
    jsAsync(
        PowerShellInstaller,
        [
            "isInstalled",
            "backupExistingFile",
            "configureProfile",
            "removeProfileConfig",
            "install",
            "uninstall",
        ],
    );
}
