import from "fs" { default as fs }
import from "http" { default as http }
import from "https" { default as https }
import from "path" { default as path }
import from "module" { createRequire }
import from "url" { fileURLToPath }
import from "node:process" { default as process }

type CliInstallInfo = any;

def:priv ownFile -> str {
    keep = globalThis.Error.prepareStackTrace;
    try {
        globalThis.Error.prepareStackTrace = lambda (e: any, sites: any) -> any { sites };
        file: any = new(globalThis.Error).stack[0].getFileName();
        return fileURLToPath(file) if file.startsWith("file:") else file;
    } finally {
        globalThis.Error.prepareStackTrace = keep;
    }
}

glob:priv PACKAGE_JSON: str = path.resolve(path.dirname(ownFile()), "../../../package.json"),
          pkg: any = createRequire(PACKAGE_JSON)(PACKAGE_JSON),
          PACKAGE_NAME: str = pkg.name,
          OPENSPEC_VERSION: str = pkg.version,
          DEFAULT_REGISTRY: str = "https://registry.npmjs.org",
          RELEASES_URL: str = "https://github.com/Fission-AI/OpenSpec/releases",
          REQUEST_TIMEOUT_MS: int = 1500,
          SAFE_VERSION: str = "^\\d{1,10}\\.\\d{1,10}\\.\\d{1,10}(?:-[0-9A-Za-z.-]{1,64})?(?:\\+[0-9A-Za-z.-]{1,64})?$",
          THEN_UPDATE: str = "  Then run \"openspec update\" again to pick up new workflows.",
          GLOBAL_UPGRADE_COMMANDS: dict[str, any] = {
              "npm": f"npm install -g {PACKAGE_NAME}@latest",
              "pnpm": f"pnpm add -g {PACKAGE_NAME}@latest",
              "bun": f"bun add -g {PACKAGE_NAME}@latest",
              "yarn": f"yarn global add {PACKAGE_NAME}@latest",
              "volta": f"volta install {PACKAGE_NAME}@latest",
              "homebrew": "brew upgrade openspec",
          },
          standaloneBinaryPath: any = JsNull;

def:priv win -> bool {
    return process.platform == "win32";
}

def:priv lower(value: any) -> any {
    return value.toLowerCase();
}

def:priv norm(value: any) -> any {
    return lower(value) if win() else value;
}

def:priv paint(style: str, text: str) -> any {
    return globalThis.Reflect.get(pick("chalk"), style)(text);
}

def:priv say(style: str, text: str) {
    globalThis.console.log(paint(style, text));
}

def:priv withoutV(text: str) -> str {
    return sub(text, "^v", "", "");
}

def markStandaloneBinary(executablePath: str) {
    standaloneBinaryPath = executablePath;
}

def getStandaloneBinaryPath -> any {
    return standaloneBinaryPath;
}

def:priv standaloneUpgradeCommand -> any {
    if not standaloneBinaryPath {
        return JsNull;
    }
    copies = findCopiesOnPath();
    if len(copies) and copies[0] and samePath(copies[0], standaloneBinaryPath) {
        return "openspec install";
    }
    binary: str = standaloneBinaryPath;
    return "& '" + binary.replace("'", "''") + "' install"
        if win()
        else "'" + binary.replace("'", "'\\''") + "' install";
}

def:priv isCheckEnabled(requested: bool) -> bool {
    if process.env["OPENSPEC_NO_UPDATE_CHECK"] is not None or process.env["NODE_ENV"] == "test" {
        return False;
    }
    return requested
        or not (
            isCiEnvironment()
            or isTelemetryOptedOutByEnv()
            or same(at(getGlobalConfig(), "telemetry", "enabled"), False)
            or isGlobalConfigUnreadable()
        );
}

def:priv configuredRegistry -> any {
    configured: any = process.env["npm_config_registry"];
    return configured.trim() if configured is not None else "";
}

def registryUrl -> any {
    configured = configuredRegistry();
    if configured and not found(configured, "^https:\\/\\/", "i") {
        return JsNull;
    }
    base = sub(configured or DEFAULT_REGISTRY, "\\/+$", "", "");
    return f"{base}/{PACKAGE_NAME}/latest";
}

def:priv isDefaultRegistry -> bool {
    configured = configuredRegistry();
    if not configured {
        return True;
    }
    try {
        return new(globalThis.URL, configured).origin
            == new(globalThis.URL, DEFAULT_REGISTRY).origin;
    } except Exception {
        return False;
    }
}

def:priv comparePrerelease(a: str, b: str) -> int {
    if a == b {
        return 0;
    }
    if not a or not b {
        return 1 if not a else -1;
    }
    (left, right) = (a.split("."), b.split("."));
    for i in range(max(len(left), len(right))) {
        if i >= len(left) or i >= len(right) {
            return -1 if i >= len(left) else 1;
        }
        (l, r) = (left[i], right[i]);
        (ln, rn) = (found(l, "^\\d+$"), found(r, "^\\d+$"));
        if ln and rn {
            diff = globalThis.Number.parseInt(l, 10) - globalThis.Number.parseInt(r, 10);
            if diff != 0 {
                return 1 if diff > 0 else -1;
            }
        } elif ln != rn {
            return -1 if ln else 1;
        } elif l != r {
            return 1 if l > r else -1;
        }
    }
    return 0;
}

def compareVersions(a: str, b: str) -> int {
    def parse(version: any) -> any {
        bare = withoutV(version.trim()).split("+")[0];
        cut = bare.find("-");
        core = bare if cut == -1 else bare[:cut];
        parts = [globalThis.Number.parseInt(n, 10) for n in core.split(".")] + [0, 0, 0];
        return ([n if truthy(n) else 0 for n in parts[:3]], "" if cut == -1 else bare[cut + 1:]);
    }
    (left, leftPre) = parse(a);
    (right, rightPre) = parse(b);
    for i in range(3) {
        if left[i] != right[i] {
            return 1 if left[i] > right[i] else -1;
        }
    }
    return comparePrerelease(leftPre, rightPre);
}

def:priv httpsGet(url: any, deadline: int, followRedirects: bool) -> any {
    def run(resolve: any) {
        settled = False;
        timer: any = None;
        active: any = None;
        redirectsLeft = 3;
        def finish(result: any) {
            if settled {
                return;
            }
            settled = True;
            if timer is not None {
                globalThis.clearTimeout(timer);
            }
            resolve(result);
        }
        def send(target: any) {
            request: any = None;
            def onResponse(response: any) {
                status = response.statusCode ?? 0;
                location = response.headers["location"];
                if 300 <= status < 400 and location {
                    response.resume();
                    request.destroy();
                    if not followRedirects {
                        finish(rec(status=status, body=""));
                        return;
                    }
                    if redirectsLeft <= 0 {
                        finish(None);
                        return;
                    }
                    redirectsLeft -= 1;
                    try {
                        next = new(globalThis.URL, location, target);
                        if next.protocol == "https:" {
                            send(next);
                            return;
                        }
                    } except Exception {}
                    finish(None);
                    return;
                }
                if status != 200 {
                    response.resume();
                    request.destroy();
                    finish(rec(status=status, body=""));
                    return;
                }
                body: any = "";
                def onData(chunk: any) {
                    body += chunk;
                    if body.length > 256 * 1024 {
                        request.destroy();
                        finish(None);
                    }
                }
                response.setEncoding("utf-8");
                response.on("data", onData);
                response.on("end", lambda -> any { finish(rec(status=status, body=body)) });
                response.on("error", lambda -> any { finish(None) });
            }
            request = (http if target.protocol == "http:" else https).get(
                target, rec(timeout=REQUEST_TIMEOUT_MS), onResponse
            );
            active = request;
            def onTimeout {
                request.destroy();
                finish(None);
            }
            request.on("timeout", onTimeout);
            request.on("error", lambda -> any { finish(None) });
            if timer is None {
                def onDeadline {
                    if active is not None {
                        active.destroy();
                    }
                    finish(None);
                }
                timer = globalThis.setTimeout(onDeadline, max(0, deadline - globalThis.Date.now()));
            }
        }
        send(url);
    }
    return new(globalThis.Promise, run);
}

async def:priv fetchLatestVersion -> any {
    url: any = None;
    try {
        resolved = registryUrl();
        if resolved is JsNull {
            return JsNull;
        }
        url = new(globalThis.URL, resolved);
    } except Exception {
        return JsNull;
    }
    response = await httpsGet(url, globalThis.Date.now() + REQUEST_TIMEOUT_MS, True);
    if missing(response) or response.status != 200 {
        return JsNull;
    }
    try {
        version = at(globalThis.JSON.parse(response.body), "version");
        return version if kind(version) == "string" and found(version, SAFE_VERSION) else JsNull;
    } except Exception {
        return JsNull;
    }
}

async def:priv fetchLatestStandaloneRelease -> any {
    deadline = globalThis.Date.now() + REQUEST_TIMEOUT_MS;
    feed = await httpsGet(new(globalThis.URL, f"{RELEASES_URL}.atom"), deadline, True);
    if missing(feed) or feed.status != 200 {
        return JsNull;
    }
    tags = globalThis.Array.from(
        feed.body.matchAll(rx("\\/releases\\/tag\\/v(\\d+\\.\\d+\\.\\d+)\"", "g"))
    );
    for version in globalThis.Array.from(new(globalThis.Set, [m[1] for m in tags])) {
        if not found(version, SAFE_VERSION) {
            continue;
        }
        if compareVersions(version, OPENSPEC_VERSION) <= 0 {
            return version;
        }
        probe = await httpsGet(
            new(globalThis.URL, f"{RELEASES_URL}/download/v{version}/SHA256SUMS"), deadline, False
        );
        if missing(probe) {
            return JsNull;
        }
        if probe.status == 200 or 300 <= probe.status < 400 {
            return version;
        }
        if probe.status != 404 {
            return JsNull;
        }
    }
    return JsNull;
}

async def checkForCliUpdate(options: any = None) -> any {
    standalone = not missing(standaloneBinaryPath);
    if not isCheckEnabled(same(at(options, "requested"), True))
        or (not standalone and registryUrl() is JsNull)
    {
        return rec(status="disabled", latest=JsNull);
    }
    try {
        latest = await (fetchLatestStandaloneRelease() if standalone else fetchLatestVersion());
        if not latest {
            return rec(status="offline", latest=JsNull);
        }
        return rec(
            status="available" if compareVersions(latest, OPENSPEC_VERSION) > 0 else "current",
            latest=latest,
        );
    } except Exception {
        return rec(status="offline", latest=JsNull);
    }
}

async def getAvailableCliUpdate -> any {
    result = await checkForCliUpdate();
    return result.latest if result.status == "available" else JsNull;
}

def getInstallDir -> any {
    if standaloneBinaryPath or not fs.existsSync(PACKAGE_JSON) {
        return JsNull;
    }
    return path.dirname(PACKAGE_JSON);
}

def isProjectLocalInstall(installDir: any, projectPath: any = None) -> bool {
    if not installDir {
        return False;
    }
    try {
        dir = FileSystemUtils.canonicalizeExistingPath(projectPath ?? ".");
        target = norm(FileSystemUtils.canonicalizeExistingPath(installDir));
        while True {
            if target.startsWith(norm(path.join(dir, "node_modules") + path.sep)) {
                return True;
            }
            parent = path.dirname(dir);
            if parent == dir {
                return False;
            }
            dir = parent;
        }
    } except Exception {
        return False;
    }
}

def:priv segmentsOf(installDir: any) -> any {
    return [
        lower(segment)
        for segment in globalThis.String.prototype.split.call(
            "" if missing(installDir) else installDir, rx("[\\\\/]")
        )
    ];
}

def:priv hasSequence(segments: any, *names: str) -> bool {
    return any([
        all([i + k < len(segments) and segments[i + k] == name for (k, name) in enumerate(names)])
        for i in range(len(segments))
    ]);
}

def isEphemeralRunnerInstall(installDir: any) -> bool {
    if not installDir {
        return False;
    }
    segments = segmentsOf(installDir);
    return any([
        segment in ["_npx", "_bunx"]
            or (
                segment == "dlx"
                and i > 0
                and segments[i - 1] in ["pnpm", "bun", ".pnpm", "pnpm-cache", "bun-cache"]
            )
        for (i, segment) in enumerate(segments)
    ]);
}

def npmGlobalRoots -> any {
    nodeDir = path.dirname(process.execPath);
    appData = process.env["APPDATA"];
    prefix = process.env["npm_config_prefix"];
    roots: any = [
        path.join(nodeDir, "node_modules")
            if win()
            else path.resolve(nodeDir, "..", "lib", "node_modules"),
    ];
    if win() and appData {
        roots.push(path.join(appData, "npm", "node_modules"));
    }
    if prefix {
        roots.push(
            path.join(prefix, "node_modules") if win() else path.join(prefix, "lib", "node_modules")
        );
    }
    return roots;
}

def npmPrefixFromInstallDir(installDir: any) -> any {
    if not installDir {
        return JsNull;
    }
    dir: any = installDir;
    while lower(path.basename(dir)) != "node_modules" {
        if path.dirname(dir) == dir {
            return JsNull;
        }
        dir = path.dirname(dir);
    }
    if path.dirname(dir) == dir {
        return JsNull;
    }
    container = path.dirname(dir);
    if win() {
        return container;
    }
    return path.dirname(container) if lower(path.basename(container)) == "lib" else JsNull;
}

def isNpmGlobalInstall(installDir: any, roots: any = None) -> bool {
    if not installDir or detectPackageManager(installDir) != "npm" {
        return False;
    }
    target = norm(installDir);
    if any([target.startsWith(norm(base + path.sep)) for base in roots ?? npmGlobalRoots()]) {
        return True;
    }
    prefix = npmPrefixFromInstallDir(installDir);
    if not prefix {
        return False;
    }
    try {
        return fs.existsSync(path.join(prefix, "openspec.cmd" if win() else "bin"));
    } except Exception {
        return False;
    }
}

def isSourceCheckout(installDir: any) -> bool {
    if not installDir {
        return False;
    }
    try {
        return fs.existsSync(path.join(installDir, ".git"));
    } except Exception {
        return False;
    }
}

def:priv detectKnownPackageManager(installDir: any) -> any {
    segments = segmentsOf(installDir);
    def anyOf(*names: str) -> bool {
        return any([name in segments for name in names]);
    }
    if hasSequence(segments, "cellar", "openspec") {
        return "homebrew";
    }
    if len(segments) > 2 and segments[0] == "" and segments[1] == "nix" and segments[2] == "store" {
        return "nix";
    }
    if anyOf(".volta") or (anyOf("volta") and anyOf("tools") and anyOf("image")) {
        return "volta";
    }
    if anyOf(".bun", "_bunx", "bun-cache") {
        return "bun";
    }
    if anyOf("_npx") {
        return "npm";
    }
    if anyOf(".pnpm", ".pnpm-global", "pnpm-cache")
        or (anyOf("pnpm") and anyOf("global", "dlx", "store"))
    {
        return "pnpm";
    }
    if anyOf(".yarn") or (anyOf("yarn") and anyOf("global")) {
        return "yarn";
    }
    return JsNull;
}

def detectPackageManager(installDir: any) -> str {
    known = detectKnownPackageManager(installDir);
    return "npm" if missing(known) else known;
}

def:priv detectGlobalPackageManager(installDir: any) -> any {
    owner = detectKnownPackageManager(installDir);
    if owner in ["homebrew", "nix"] {
        return owner;
    }
    if isNpmGlobalInstall(installDir) {
        return "npm";
    }
    if not installDir {
        return JsNull;
    }
    segments = segmentsOf(installDir);
    if hasSequence(segments, ".volta", "tools", "image")
        or hasSequence(segments, "volta", "tools", "image")
    {
        return "volta";
    }
    if ".pnpm-global" in segments or hasSequence(segments, "pnpm", "global") {
        return "pnpm";
    }
    if hasSequence(segments, "yarn", "global") or hasSequence(segments, "yarn", "data", "global") {
        return "yarn";
    }
    return "bun" if hasSequence(segments, ".bun", "install", "global") else JsNull;
}

def:priv installInfo(location: any, packageManager: any, scope: any) -> any {
    return rec(location=location, packageManager=packageManager, scope=scope);
}

def getCliInstallInfo(installDir: any = None, projectPath: any = None) -> any {
    if standaloneBinaryPath {
        return installInfo(path.dirname(standaloneBinaryPath), JsNull, "standalone");
    }
    if installDir is None {
        installDir = getInstallDir();
    }
    if not installDir {
        return installInfo(JsNull, JsNull, JsNull);
    }
    if isSourceCheckout(installDir) {
        return installInfo(installDir, JsNull, "source");
    }
    if isEphemeralRunnerInstall(installDir) {
        return installInfo(installDir, detectKnownPackageManager(installDir), "temporary");
    }
    if isProjectLocalInstall(installDir, projectPath) {
        return installInfo(installDir, detectKnownPackageManager(installDir), "project");
    }
    packageManager = detectGlobalPackageManager(installDir);
    return installInfo(installDir, packageManager, "global" if packageManager else JsNull);
}

def getCliUpdateCommand(install: any) -> any {
    if install["scope"] == "standalone" {
        return standaloneUpgradeCommand();
    }
    if install["scope"] != "global" or missing(install["packageManager"]) {
        return JsNull;
    }
    return GLOBAL_UPGRADE_COMMANDS.get(install["packageManager"]) or JsNull;
}

def buildVersionReportLines(
    version: str, install: any, update: any = None, command: any = None
) -> any {
    details = ", ".join([
        part
        for part in [install["packageManager"], install["scope"]]
        if truthy(part)
    ]);
    lines: any = [f"OpenSpec {version} ({details})" if details else f"OpenSpec {version}"];
    if missing(update) {
        return lines;
    }
    status = update["status"];
    if status == "available" {
        lines.push(f"Update available: {globalThis.String(update['latest'])}");
        if command {
            lines.push(f"  {command}");
        }
    } else {
        lines.push(
            "OpenSpec is up to date."
                if status == "current"
                else "Update check disabled."
                    if status == "disabled"
                    else "Could not check for updates.",
        );
    }
    return lines;
}

def buildCliUpdateLines(
    latestVersion: str, installDir: any, projectPath: any, options: any = None
) -> any {
    lines: any = [f"A newer OpenSpec CLI is available (v{OPENSPEC_VERSION} → v{latestVersion})."];
    if not same(at(options, "withCommand"), False) {
        lines = lines + buildUpgradeCommandLines(installDir, projectPath);
    }
    if installDir {
        lines.push(f"  Running from: {installDir}");
    }
    return lines;
}

def buildUpgradeCommandLines(installDir: any, projectPath: any) -> any {
    standalone = standaloneUpgradeCommand();
    if standalone {
        return [f"  {standalone}", THEN_UPDATE];
    }
    if isEphemeralRunnerInstall(installDir) {
        return [f"  npx {PACKAGE_NAME}@latest update"];
    }
    if isProjectLocalInstall(installDir, projectPath) {
        return [f"  Update the {PACKAGE_NAME} dependency in this project.", THEN_UPDATE];
    }
    command = GLOBAL_UPGRADE_COMMANDS.get(detectPackageManager(installDir));
    return [
        f"  {command}" if command else "  Update OpenSpec through Nix, the way you installed it.",
        THEN_UPDATE,
    ];
}

def canSelfUpgrade(installDir: any, projectPath: any) -> bool {
    return truthy(installDir)
        and isDefaultRegistry()
        and not isEphemeralRunnerInstall(installDir)
        and not isProjectLocalInstall(installDir, projectPath)
        and not isProjectLocalInstall(installDir)
        and not isSourceCheckout(installDir)
        and isNpmGlobalInstall(installDir);
}

def shouldOfferUpgrade(params: any) -> bool {
    return truthy(params["interactive"])
        and truthy(params["stdoutIsTty"])
        and canSelfUpgrade(params["installDir"], params["projectPath"]);
}

def:priv launch(command: str, args: any, options: any) -> any {
    return need("cross-spawn")(command, args, options);
}

def:priv runGlobalUpgrade -> any {
    def run(resolve: any) {
        child = launch("npm", ["install", "-g", f"{PACKAGE_NAME}@latest"], rec(stdio="inherit"));
        child.on("error", lambda -> any { resolve(False) });
        child.on("close", lambda (code: any) -> any { resolve(same(code, 0)) });
    }
    return new(globalThis.Promise, run);
}

def upgradedBinPath(roots: any = None, installDir: any = None) -> any {
    if installDir is None {
        installDir = getInstallDir();
    }
    ownPrefix = npmPrefixFromInstallDir(installDir);
    first: any = [];
    if ownPrefix {
        first = [
            path.join(ownPrefix, "node_modules")
                if win()
                else path.join(ownPrefix, "lib", "node_modules"),
        ];
    }
    for base in first + (roots ?? npmGlobalRoots()) {
        candidate = path.join(path.dirname(base), "openspec.cmd")
            if win()
            else path.resolve(base, "..", "..", "bin", "openspec");
        try {
            if fs.existsSync(candidate) {
                return candidate;
            }
        } except Exception {}
    }
    return JsNull;
}

def readCliVersion(binPath: str) -> any {
    def run(resolve: any) {
        output: any = "";
        child: any = None;
        try {
            child = launch(binPath, ["--version"], rec(stdio=["ignore", "pipe", "ignore"]));
        } except Exception {
            resolve(JsNull);
            return;
        }
        child.unref();
        def onTimeout {
            child.kill("SIGKILL");
            resolve(JsNull);
        }
        timer = globalThis.setTimeout(onTimeout, 5000);
        def onData(chunk: any) {
            output += chunk.toString();
        }
        def onError {
            globalThis.clearTimeout(timer);
            resolve(JsNull);
        }
        def onClose {
            globalThis.clearTimeout(timer);
            versions = [
                withoutV(line)
                for line in [
                    raw.trim()
                    for raw in globalThis.String.prototype.split.call(output, rx("\\r?\\n"))
                ]
                if found(withoutV(line), SAFE_VERSION)
            ];
            resolve(versions[-1] if versions else JsNull);
        }
        if not missing(child["stdout"]) {
            child.stdout.on("data", onData);
        }
        child.on("error", onError);
        child.on("close", onClose);
    }
    return new(globalThis.Promise, run);
}

async def offerCliUpgrade(latestVersion: str) -> str {
    confirm = merge(await load("@inquirer/prompts")).confirm;
    accepted: any = False;
    try {
        accepted = await confirm(
            globalThis.Object.fromEntries([
                ["message", f"Upgrade to v{latestVersion} now?"],
                ["default", True],
            ]),
        );
    } except Exception as e {
        return "cancelled"
            if at(js_error(e), "name") in ["ExitPromptError", "AbortPromptError"]
            else "declined";
    }
    if not accepted {
        return "declined";
    }
    globalThis.console.log();
    installed = await runGlobalUpgrade();
    globalThis.console.log();
    if not installed {
        say("yellow", "The upgrade did not complete. A global install may need");
        say("yellow", "elevated permissions, or a different package manager.");
        return "failed";
    }
    binPath = upgradedBinPath();
    version = await readCliVersion("openspec" if missing(binPath) else binPath);
    if not version {
        say("yellow", "Upgrade finished, but no \"openspec\" could be run to confirm it.");
        return "not-on-path";
    }
    if compareVersions(version, OPENSPEC_VERSION) <= 0 {
        say("yellow", f"Upgrade finished, but \"openspec\" still reports v{version}.");
        say(
            "dim",
            f"  npm reported success, but {binPath} did not change."
                if not missing(binPath)
                else "  Another install earlier on your PATH is answering first.",
        );
        return "not-on-path";
    }
    say("green", f"✓ Upgraded to v{version}.");
    return "upgraded";
}

async def rerunUpdateWithUpgradedCli(projectPath: str, options: any = None) -> any {
    binPath: any = at(options, "binPath");
    if missing(binPath) {
        binPath = upgradedBinPath();
    }
    if missing(binPath) {
        binPath = "openspec";
    }
    args = ["update", *(["--force"] if at(options, "force") else []), "--", projectPath];
    def run(resolve: any) {
        env = merge(process.env, rec(OPENSPEC_NO_UPDATE_CHECK="1", OPENSPEC_TELEMETRY="0"));
        child = launch(binPath, args, rec(stdio="inherit", env=env));
        def onError {
            say("yellow", "Instruction files were not regenerated.");
            say("dim", "  Run \"openspec update\" to pick up the new workflows.");
            resolve(1);
        }
        child.on("error", onError);
        child.on("close", lambda (code: any) -> any { resolve(1 if missing(code) else code) });
    }
    return await new(globalThis.Promise, run);
}

def displayCliUpdateNote(latestVersion: str, projectPath: str = ".", options: any = None) {
    lines = buildCliUpdateLines(latestVersion, getInstallDir(), projectPath, options);
    globalThis.console.log();
    say("yellow", lines[0]);
    for line in lines[1:] {
        say("dim", line);
    }
}

def displayUpgradeCommand(projectPath: str = ".") {
    for line in buildUpgradeCommandLines(getInstallDir(), projectPath) {
        say("dim", line);
    }
}
