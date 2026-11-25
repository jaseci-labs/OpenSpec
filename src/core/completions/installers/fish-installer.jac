import from "node:path" { join }
import from "node:os" { homedir }

obj FishInstaller(globalThis.Object) {
    def init(homeDir: str = homedir()) {
        super.init();
        self.homeDir = homeDir;
    }

    def getInstallationPath -> str {
        return join(self.homeDir, ".config", "fish", "completions", "openspec.fish");
    }

    async def isInstalled -> bool {
        return await isScriptFile(self.getInstallationPath());
    }

    async def backupExistingFile(targetPath: str) -> any {
        return await backupFile(targetPath);
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
                        "Fish automatically loads completions - they should be available immediately.",
                    ],
                );
            }
            (updated, backupPath) = placed;
            return rec(
                success=True,
                installedPath=targetPath,
                backupPath=backupPath,
                message=updated or "Completion script installed successfully for Fish",
                instructions=[
                    "Fish automatically loads completions from ~/.config/fish/completions/",
                    "Completions are available immediately - no shell restart needed.",
                ],
            );
        } except Exception as e {
            return failed("install", e);
        }
    }

    async def uninstall(options: any = None) -> any {
        return await uninstallScript(self.getInstallationPath(), True);
    }
}

with entry {
    jsAsync(FishInstaller, ["isInstalled", "backupExistingFile", "install", "uninstall"]);
}
