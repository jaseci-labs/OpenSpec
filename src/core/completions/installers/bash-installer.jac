import from "node:fs" { promises as fs }
import from "node:path" { join, dirname }
import from "node:os" { homedir }

glob:priv COMPLETION_DIRS: list[str] = [
    "/usr/share/bash-completion",
    "/usr/local/share/bash-completion",
    "/opt/homebrew/etc/bash_completion.d",
    "/usr/local/etc/bash_completion.d",
    "/etc/bash_completion.d",
];

def:priv sourceLines(quotedDir: str, i: str) -> list[str] {
    return [
        f"{i}if [ -d {quotedDir} ]; then",
        f"{i}  for f in {quotedDir}/*; do",
        f'{i}    [ -f "$f" ] && . "$f"',
        f"{i}  done",
        f"{i}fi",
    ];
}

obj BashInstaller(globalThis.Object) {
    def init(homeDir: any = None) {
        super.init();
        self.homeDir = homeDir ?? homedir();
    }

    async def isBashCompletionInstalled -> bool {
        for p in COMPLETION_DIRS {
            try {
                if (await fs.stat(p)).isDirectory() {
                    return True;
                }
            } except Exception {}
        }
        return False;
    }

    async def getInstallationPath -> str {
        return join(self.homeDir, ".local", "share", "bash-completion", "completions", "openspec");
    }

    async def isInstalled -> bool {
        return await isScriptFile(await self.getInstallationPath());
    }

    async def backupExistingFile(targetPath: str) -> any {
        return await backupFile(targetPath);
    }

    async def configureBashrc(completionsDir: str) -> bool {
        config = [
            "# OpenSpec shell completions configuration",
            *sourceLines(shellSingleQuote(completionsDir), ""),
        ];
        return await configureRc(join(self.homeDir, ".bashrc"), "\n".join(config), ".bashrc");
    }

    async def removeBashrcConfig -> bool {
        return await removeRcBlock(join(self.homeDir, ".bashrc"), ".bashrc");
    }

    async def install(completionScript: str) -> any {
        try {
            targetPath = await self.getInstallationPath();
            hasBashCompletion = await self.isBashCompletionInstalled();
            placed = await placeScript(self, targetPath, completionScript);
            if placed is None {
                return rec(
                    success=True,
                    installedPath=targetPath,
                    message=UP_TO_DATE,
                    instructions=[
                        "The completion script is already installed and up to date.",
                        "If completions are not working, try: exec bash",
                    ],
                );
            }
            (updated, backupPath) = placed;
            configured = await self.configureBashrc(dirname(targetPath));
            return rec(
                success=True,
                installedPath=targetPath,
                backupPath=backupPath,
                bashrcConfigured=configured,
                message=updated
                    or (
                        "Completion script installed and .bashrc configured successfully"
                            if configured
                            else "Completion script installed successfully for Bash"
                    ),
                instructions=None
                    if configured
                    else [
                        "Completion script installed successfully.",
                        "",
                        "To enable completions, add the following to your ~/.bashrc file:",
                        "",
                        "  # Source OpenSpec completions",
                        *sourceLines(shellSingleQuote(dirname(targetPath)), "  "),
                        "",
                        "Then restart your shell or run: exec bash",
                    ],
                warnings=None
                    if hasBashCompletion
                    else [
                        "⚠️  Warning: bash-completion package not detected",
                        "",
                        "The completion script requires bash-completion to function.",
                        "Install it with:",
                        "  brew install bash-completion@2",
                        "",
                        "Then add to your ~/.bash_profile:",
                        '  [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"',
                    ],
            );
        } except Exception as e {
            return failed("install", e);
        }
    }

    async def uninstall(options: any = None) -> any {
        return await uninstallScript(
            await self.getInstallationPath(), False, lambda -> any { self.removeBashrcConfig() }
        );
    }
}

with entry {
    jsAsync(
        BashInstaller,
        [
            "isBashCompletionInstalled",
            "getInstallationPath",
            "isInstalled",
            "backupExistingFile",
            "configureBashrc",
            "removeBashrcConfig",
            "install",
            "uninstall",
        ],
    );
}
