import from "node:child_process" { spawn as launch }
import from "node:os" { default as os }
import from "node:path" { default as path }
import from "node:process" { default as process }

type InstallTarget = any;

glob:priv INSTALLER_BASE: str = "https://raw.githubusercontent.com/Fission-AI/OpenSpec/main/scripts/binary",
          RELEASE_VERSION: str = "^v?\\d{1,10}\\.\\d{1,10}\\.\\d{1,10}(?:-[0-9A-Za-z.-]{1,64})?$",
          POSIX_RUNNER: str = "f=$(mktemp) || exit 1; { curl -fsSL \"$1\" -o \"$f\" 2>/dev/null || wget -q -O \"$f\" \"$1\"; } && sh \"$f\"; s=$?; rm -f \"$f\"; exit $s",
          REMOVE_COMMANDS: dict[str, str] = {
              "homebrew": "brew uninstall openspec",
              "npm": "npm uninstall -g @fission-ai/openspec",
              "pnpm": "pnpm remove -g @fission-ai/openspec",
              "yarn": "yarn global remove @fission-ai/openspec",
              "bun": "bun remove -g @fission-ai/openspec",
              "volta": "volta uninstall @fission-ai/openspec",
          };

def:priv defaultName(platform: str) -> str {
    return "openspec.exe" if platform == "win32" else "openspec";
}

def resolveInstallTarget(env: any = None, platform: any = None, standalonePath: any = None) -> any {
    env = env ?? process.env;
    platform = platform ?? process.platform;
    if standalonePath is None {
        standalonePath = getStandaloneBinaryPath();
    }
    if env["OPENSPEC_INSTALL_DIR"] {
        return rec(
            dir=path.resolve(env["OPENSPEC_INSTALL_DIR"]),
            name=env["OPENSPEC_INSTALL_NAME"] or defaultName(platform),
        );
    }
    if standalonePath {
        return rec(dir=path.dirname(standalonePath), name=path.basename(standalonePath));
    }
    if platform == "win32" {
        localAppData = env["LOCALAPPDATA"] or path.join(os.homedir(), "AppData", "Local");
        return rec(dir=path.join(localAppData, "Programs", "openspec"), name=defaultName(platform));
    }
    return rec(dir=path.join(os.homedir(), ".local", "bin"), name=defaultName(platform));
}

def removeCommandFor(install: any) -> any {
    if install["scope"] != "global" {
        return JsNull;
    }
    return REMOVE_COMMANDS.get(install["packageManager"]) or JsNull;
}

def checkSource(label: str, value: str) -> str {
    url: any = None;
    try {
        url = new(globalThis.URL, value);
    } except Exception {
        raise new(globalThis.Error, f"{label} is not a URL: {value}");
    }
    local = url.hostname in ["localhost", "127.0.0.1", "[::1]"];
    if url.username
        or url.password
        or (url.protocol != "https:" and not (url.protocol == "http:" and local))
    {
        raise new(globalThis.Error, f"{label} must use https (or http to localhost): {value}");
    }
    return sub(url.href, "\\/+$", "", "");
}

def installerBase(env: any = None) -> str {
    env = env ?? process.env;
    if env["OPENSPEC_RELEASES_URL"] {
        checkSource("OPENSPEC_RELEASES_URL", env["OPENSPEC_RELEASES_URL"]);
    }
    download = env["OPENSPEC_DOWNLOAD_URL"];
    return checkSource("OPENSPEC_DOWNLOAD_URL", download) if download else INSTALLER_BASE;
}

def:priv runInstaller(scriptUrl: str, env: any) -> any {
    windows = process.platform == "win32";
    def run(resolve: any, reject: any) {
        child = launch(
            "powershell.exe" if windows else "sh",
            [
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                "irm $env:OPENSPEC_INSTALLER_URL | iex",
            ]
                if windows
                else ["-c", POSIX_RUNNER, "openspec-install", scriptUrl],
            rec(
                stdio="inherit",
                env=merge(env, rec(OPENSPEC_INSTALLER_URL=scriptUrl)) if windows else env,
            ),
        );
        child.on("error", reject);
        child.on("close", lambda (code: any) -> any { resolve(1 if missing(code) else code) });
    }
    return new(globalThis.Promise, run);
}

async def installStandalone(options: any = None) {
    version = at(options, "version");
    pinned = version and version != "latest";
    if pinned and not found(version, RELEASE_VERSION) {
        raise new(
            globalThis.Error,
            f"Not a release version: {version}. Use one like 1.15.0, or leave it out for the latest.",
        );
    }
    scriptUrl = installerBase()
        + "/"
        + ("install.ps1" if process.platform == "win32" else "install.sh");
    target = resolveInstallTarget();
    exitCode = await runInstaller(
        scriptUrl,
        merge(
            process.env,
            rec(OPENSPEC_INSTALL_DIR=target.dir, OPENSPEC_INSTALL_NAME=target.name),
            rec(OPENSPEC_VERSION=version) if pinned else None,
        ),
    );
    if exitCode != 0 {
        raise new(
            globalThis.Error, f"The standalone install did not finish (installer: {scriptUrl})."
        );
    }
    copies = findCopiesOnPath() if target.name == defaultName(process.platform) else [];
    first: any = copies[0] if len(copies) else None;
    runsStandalone = first is not None and samePath(first, path.join(target.dir, target.name));
    remove = JsNull if getStandaloneBinaryPath() else removeCommandFor(getCliInstallInfo());
    globalThis.console.log();
    if runsStandalone {
        globalThis.console.log("openspec now runs the standalone copy.");
    } elif first {
        globalThis.console.log(f"{first} comes first on your PATH, so it still runs.");
    } elif target.name == defaultName(process.platform) {
        globalThis.console.log("Open a new terminal so it picks up the new PATH.");
    }
    if remove {
        globalThis.console.log(
            "To remove your package-manager copy:"
                if runsStandalone
                else "To switch, remove your package-manager copy:",
        );
        globalThis.console.log(pick("chalk").cyan(f"  {remove}"));
    }
    globalThis.console.log(
        pick("chalk").dim("Check with 'openspec version'; it shows (standalone).")
    );
}
