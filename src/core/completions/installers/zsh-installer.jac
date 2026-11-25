import from "node:fs" { promises as fs }
import from "node:path" { join, dirname, isAbsolute }
import from "node:os" { homedir }
import from "node:process" { default as process }

def:priv zshrcDir(homeDir: str) -> str {
    zdotdir = process.env.ZDOTDIR;
    return zdotdir if zdotdir and isAbsolute(zdotdir) else homeDir;
}

def:priv homeLabel(zshrcPath: str, homeDir: str) -> str {
    return "~/.zshrc" if zshrcPath == join(homeDir, ".zshrc") else zshrcPath;
}

def zshrcDisplayPath(homeDir: str = homedir()) -> str {
    return homeLabel(join(zshrcDir(homeDir), ".zshrc"), homeDir);
}

async def:priv hasMarkers(zshrcPath: str) -> bool {
    try {
        content: str = await fs.readFile(zshrcPath, "utf-8");
        return START_MARKER in content and END_MARKER in content;
    } except Exception {
        return False;
    }
}

obj ZshInstaller(globalThis.Object) {
    def init(homeDir: str = homedir()) {
        super.init();
        self.homeDir = homeDir;
    }

    async def isOhMyZshInstalled -> bool {
        if process.env.ZSH {
            return True;
        }
        try {
            return (await fs.stat(self.ohMyZshRoot())).isDirectory();
        } except Exception {
            return False;
        }
    }

    def ohMyZshRoot -> str {
        return process.env.ZSH or join(self.homeDir, ".oh-my-zsh");
    }

    async def getInstallationPath -> any {
        if await self.isOhMyZshInstalled() {
            return rec(
                path=join(
                    process.env.ZSH_CUSTOM or join(self.ohMyZshRoot(), "custom"),
                    "completions",
                    "_openspec",
                ),
                isOhMyZsh=True,
            );
        }
        return rec(path=join(self.homeDir, ".zsh", "completions", "_openspec"), isOhMyZsh=False);
    }

    async def backupExistingFile(targetPath: str) -> any {
        return await backupFile(targetPath);
    }

    def zshrcPath -> str {
        return join(zshrcDir(self.homeDir), ".zshrc");
    }

    async def configureZshrc(completionsDir: str) -> bool {
        config = [
            "# OpenSpec shell completions configuration",
            f"fpath=({shellSingleQuote(completionsDir)} $fpath)",
            "autoload -Uz compinit",
            "compinit",
        ];
        return await configureRc(self.zshrcPath(), "\n".join(config), ".zshrc");
    }

    async def removeZshrcConfig(zshrcPath: any = None) -> bool {
        return await removeRcBlock(zshrcPath ?? self.zshrcPath(), ".zshrc");
    }

    async def install(completionScript: str) -> any {
        try {
            location = await self.getInstallationPath();
            (targetPath, isOhMyZsh) = (location.path, location.isOhMyZsh);
            targetDir = dirname(targetPath);
            placed = await placeScript(self, targetPath, completionScript);
            configured = False if isOhMyZsh else await self.configureZshrc(targetDir);
            if placed is None {
                return rec(
                    success=True,
                    installedPath=targetPath,
                    isOhMyZsh=isOhMyZsh,
                    zshrcConfigured=configured,
                    message=UP_TO_DATE,
                    instructions=[
                        "The completion script is already installed and up to date.",
                        "If completions are not working, try: exec zsh",
                    ]
                        if isOhMyZsh or configured
                        else self.instructions(False, targetPath),
                );
            }
            (updated, backupPath) = placed;
            instructions = None if configured else self.instructions(isOhMyZsh, targetPath);
            if isOhMyZsh {
                quotedDir = "'" + targetDir.replace("'", "'\\''") + "'";
                instructions = instructions + [
                    "",
                    "Note: Oh My Zsh typically auto-loads completions from custom/completions.",
                    f"Verify that {targetDir} is in your fpath by running:",
                    f"  printf '%s\\n' $fpath | grep -F {quotedDir}",
                    "",
                    "If not found, completions may not work. Restart your shell to ensure changes take effect.",
                ];
            }
            return rec(
                success=True,
                installedPath=targetPath,
                backupPath=backupPath,
                isOhMyZsh=isOhMyZsh,
                zshrcConfigured=configured,
                message=updated
                    or (
                        "Completion script installed successfully for Oh My Zsh"
                            if isOhMyZsh
                            else "Completion script installed and .zshrc configured successfully"
                                if configured
                                else "Completion script installed successfully for Zsh"
                    ),
                instructions=instructions,
            );
        } except Exception as e {
            return failed("install", e, rec(isOhMyZsh=False));
        }
    }

    def instructions(isOhMyZsh: bool, installedPath: str) -> list[str] {
        if isOhMyZsh {
            return [
                "Completion script installed to Oh My Zsh completions directory.",
                "Restart your shell or run: exec zsh",
                "Completions should activate automatically.",
            ];
        }
        return [
            "Completion script installed to ~/.zsh/completions/",
            "",
            f"To enable completions, add the following to your {zshrcDisplayPath(self.homeDir)} file:",
            "",
            "  # Add completions directory to fpath",
            f"  fpath=({shellSingleQuote(dirname(installedPath))} $fpath)",
            "",
            "  # Initialize completion system",
            "  autoload -Uz compinit",
            "  compinit",
            "",
            "Then restart your shell or run: exec zsh",
            "",
            f"Check if these lines already exist in {self.zshrcPath()} before adding.",
        ];
    }

    async def uninstall -> any {
        try {
            location = await self.getInstallationPath();
            targetPath = location.path;
            scriptRemoved = True;
            try {
                await fs.access(targetPath);
                await fs.unlink(targetPath);
            } except Exception {
                scriptRemoved = False;
            }
            zshrcWasPresent = False;
            (cleaned, failedPaths) = ([], []);
            candidates = [self.zshrcPath()];
            if join(self.homeDir, ".zshrc") not in candidates {
                candidates.append(join(self.homeDir, ".zshrc"));
            }
            if not location.isOhMyZsh {
                for zshrcPath in candidates {
                    if await hasMarkers(zshrcPath) {
                        zshrcWasPresent = True;
                        (
                            cleaned if await self.removeZshrcConfig(zshrcPath) else failedPaths
                        ).append(zshrcPath);
                    }
                }
            }
            if not scriptRemoved and not zshrcWasPresent {
                return rec(success=False, message="Completion script is not installed");
            }
            messages = ([f"Completion script removed from {targetPath}"] if scriptRemoved else [])
                + [
                    f"Removed OpenSpec configuration from {homeLabel(z, self.homeDir)}"
                    for z in cleaned
                ]
                + [
                    f"Could not remove the OpenSpec block from {homeLabel(z, self.homeDir)}; delete the lines between # OPENSPEC:START and # OPENSPEC:END by hand"
                    for z in failedPaths
                ];
            return rec(success=not failedPaths, message=". ".join(messages));
        } except Exception as e {
            return failed("uninstall", e);
        }
    }

    async def isInstalled -> bool {
        try {
            await fs.access((await self.getInstallationPath()).path);
            return True;
        } except Exception {
            return False;
        }
    }

    async def getInstallationInfo -> any {
        if not await self.isInstalled() {
            return rec(installed=False);
        }
        location = await self.getInstallationPath();
        return rec(installed=True, path=location.path, isOhMyZsh=location.isOhMyZsh);
    }
}

with entry {
    jsAsync(
        ZshInstaller,
        [
            "isOhMyZshInstalled",
            "getInstallationPath",
            "backupExistingFile",
            "configureZshrc",
            "removeZshrcConfig",
            "install",
            "uninstall",
            "isInstalled",
            "getInstallationInfo",
        ],
    );
}
