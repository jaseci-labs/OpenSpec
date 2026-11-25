import from "node:process" { default as process }

glob:priv CONFIGURED: list[str] = ["zshrcConfigured", "bashrcConfigured", "profileConfigured"],
          RELOAD: dict[str, str] = {
              "zsh": "exec zsh",
              "bash": "exec bash",
              "fish": "exec fish",
              "powershell": ". $PROFILE",
          },
          RC_FILES: dict[str, str] = {
              "bash": "~/.bashrc",
              "fish": "~/.config/fish/config.fish",
              "powershell": "$PROFILE",
          },
          UNINSTALL_TARGETS: dict[str, str] = {
              "bash": "~/.bashrc",
              "fish": "Fish configuration",
              "powershell": "$PROFILE",
          };

def:priv log(text: any) {
    globalThis.console.log(text);
}

def:priv fail(text: str) -> any {
    globalThis.console.error(text);
    process.exitCode = 1;
    return None;
}

def:priv logBlock(lines: any) -> bool {
    if not lines {
        return False;
    }
    log("");
    for line in lines {
        log(line);
    }
    return True;
}

async def:priv spin(text: str) -> any {
    return (await load("ora")).default(text).start();
}

obj CompletionCommand(globalThis.Object) {
    def init {
        super.init();
        self.completionProvider = CompletionProvider();
    }

    def resolveShellOrExit(shell: any, operationName: str) -> any {
        supported = ", ".join(CompletionFactory.getSupportedShells());
        normalized = shell.toLowerCase() if shell else None;
        if not normalized {
            detection = detectShell();
            if detection["shell"] and CompletionFactory.isSupported(detection["shell"]) {
                return detection["shell"];
            }
            if detection["detected"] and not detection["shell"] {
                return fail(
                    f"Error: Shell '{detection['detected']}' is not supported yet. Currently supported: {supported}",
                );
            }
            globalThis.console.error(
                "Error: Could not auto-detect shell. Please specify shell explicitly."
            );
            globalThis.console.error(f"Usage: openspec completion {operationName} [shell]");
            return fail(f"Currently supported: {supported}");
        }
        if not CompletionFactory.isSupported(normalized) {
            return fail(
                f"Error: Shell '{normalized}' is not supported yet. Currently supported: {supported}",
            );
        }
        return normalized;
    }

    async def generate(options: any = None) {
        shell = self.resolveShellOrExit(at(options, "shell"), "generate");
        if shell {
            log(CompletionFactory.createGenerator(shell).generate(COMMAND_REGISTRY));
        }
    }

    async def install(options: any = None) {
        shell = self.resolveShellOrExit(at(options, "shell"), "install");
        if not shell {
            return;
        }
        generator = CompletionFactory.createGenerator(shell);
        installer = CompletionFactory.createInstaller(shell);
        spinner = await spin(f"Installing {shell} completion script...");
        try {
            result = await installer.install(generator.generate(COMMAND_REGISTRY));
            spinner.stop();
            if not truthy(result.success) {
                fail(f"✗ {result.message}");
                return;
            }
            log(f"✓ {result.message}");
            configured = any([truthy(result[k]) for k in CONFIGURED]);
            if truthy(at(options, "verbose")) and truthy(result["installedPath"]) {
                log(f"  Installed to: {result.installedPath}");
                if truthy(result["backupPath"]) {
                    log(f"  Backup created: {result.backupPath}");
                }
                if configured {
                    rc = zshrcDisplayPath() if shell == "zsh" else RC_FILES[shell];
                    log(f"  {rc} configured automatically");
                }
            }
            logBlock(result["warnings"]);
            if not logBlock(result["instructions"]) and configured {
                log("");
                log(f"Restart your shell or run: {RELOAD[shell]}");
            }
        } except Exception as e {
            spinner.stop();
            fail(f"✗ Failed to install completion script: {errorText(e)}");
        }
    }

    async def uninstall(options: any = None) {
        shell = self.resolveShellOrExit(at(options, "shell"), "uninstall");
        if not shell {
            return;
        }
        installer = CompletionFactory.createInstaller(shell);
        if not truthy(at(options, "yes")) {
            target = UNINSTALL_TARGETS.get(shell, "");
            if shell == "zsh" {
                zshrc = zshrcDisplayPath();
                target = zshrc
                    if zshrc == "~/.zshrc"
                    else f"{zshrc} (and ~/.zshrc if an older install wrote there)";
            }
            confirmed = await (await load("@inquirer/prompts")).confirm(
                globalThis.Object.fromEntries([
                    ["message", f"Remove OpenSpec configuration from {target}?"],
                    ["default", False],
                ]),
            );
            if not confirmed {
                log("Uninstall cancelled.");
                return;
            }
        }
        spinner = await spin(f"Uninstalling {shell} completion script...");
        try {
            result = await installer.uninstall();
            spinner.stop();
            if truthy(result.success) {
                log(f"✓ {result.message}");
            } else {
                fail(f"✗ {result.message}");
            }
        } except Exception as e {
            spinner.stop();
            fail(f"✗ Failed to uninstall completion script: {errorText(e)}");
        }
    }

    async def complete(options: any) {
        kind_: any = options["type"].toLowerCase();
        ids: any = None;
        label = "";
        try {
            if kind_ == "changes" {
                ids = await self.completionProvider.getChangeIds();
                label = "active change";
            } elif kind_ == "specs" {
                ids = await self.completionProvider.getSpecIds();
                label = "specification";
            } elif kind_ == "schemas" {
                ids = await self.completionProvider.getSchemaNames();
                label = "schema";
            } elif kind_ == "archived-changes" {
                ids = await getArchivedChangeIds();
                label = "archived change";
            } else {
                process.exitCode = 1;
                return;
            }
            for id in ids {
                log(f"{id}\t{label}");
            }
        } except Exception {
            process.exitCode = 1;
        }
    }
}

with entry {
    jsAsync(CompletionCommand, ["generate", "install", "uninstall", "complete"]);
}
