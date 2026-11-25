import from "child_process" { execFileSync }
import from "node:path" { join }
import from "os" { default as os }
import from "node:process" { default as process }

glob:priv MAX_TITLE_LENGTH: int = 72,
          TITLE_PREFIX: str = "Feedback: ",
          REPRO_PROMPT: str = "_Not provided — filed with `openspec feedback`. If this is a bug, please add the shortest steps that reproduce it from a fresh project._";

def:priv ghRuns(cmd: str, args: list[str]) -> bool {
    try {
        execFileSync(cmd, args, rec(stdio="pipe"));
        return True;
    } except Exception {
        return False;
    }
}

def:priv getVersion -> any {
    try {
        return need(join(packageRoot(), "package.json"))["version"];
    } except Exception {
        return "unknown";
    }
}

def:priv points(text: str) -> int {
    return len(globalThis.Array.from(text));
}

def:priv formatTitle(message: str) -> str {
    text = sub(message, "\\s+", " ").strip();
    if points(TITLE_PREFIX + text) <= MAX_TITLE_LENGTH {
        return TITLE_PREFIX + text;
    }
    room = MAX_TITLE_LENGTH - len(TITLE_PREFIX) - 1;
    candidate: any = "";
    for part in new(globalThis.Intl.Segmenter, None, rec(granularity="grapheme")).segment(text) {
        room -= points(part.segment);
        if room < 0 {
            break;
        }
        candidate += part.segment;
    }
    candidate = candidate.trimEnd();
    cut = candidate.lastIndexOf(" ");
    return f"{TITLE_PREFIX}{candidate.slice(0, cut) if cut > 0 else candidate}…";
}

def:priv formatBody(message: str, bodyText: any) -> str {
    return "\n".join([
        "### What happened",
        "",
        message,
        *(["", "### Details", "", bodyText] if bodyText else []),
        "",
        "### Minimal steps to reproduce",
        "",
        REPRO_PROMPT,
        "",
        f"---\nSubmitted via OpenSpec CLI\n- Version: {getVersion()}\n- Platform: {os.platform()}\n- Timestamp: {new(globalThis.Date).toISOString()}",
    ]);
}

def:priv showManual(title: str, body: str, url: str) {
    globalThis.console.log("\n--- FORMATTED FEEDBACK ---");
    globalThis.console.log(f"Title: {title}");
    globalThis.console.log("Labels: feedback");
    globalThis.console.log("\nBody:");
    globalThis.console.log(body);
    globalThis.console.log("--- END FEEDBACK ---\n");
    globalThis.console.log("Please submit your feedback manually:");
    globalThis.console.log(url);
}

def:priv reportGhFailure(error: any, title: str, body: str, url: str) {
    if truthy(error["stderr"]) {
        globalThis.console.error(error.stderr.toString());
    } elif truthy(error["message"]) {
        globalThis.console.error(error.message);
    }
    showManual(title, body, url);
    process.exit(1 if missing(error["status"]) else error.status);
}

def:priv submitViaGhCli(title: str, body: str, url: str) {
    issueUrl = "";
    labelled = True;
    for attempt in [True, False] {
        labelled = attempt;
        try {
            issueUrl = execFileSync(
                "gh",
                [
                    "issue",
                    "create",
                    "--repo",
                    "Fission-AI/OpenSpec",
                    "--title",
                    title,
                    "--body",
                    body,
                    *(["--label", "feedback"] if labelled else []),
                ],
                rec(encoding="utf-8", stdio="pipe"),
            ).trim();
            break;
        } except Exception as e {
            err = js_error(e);
            stderr = at(err, "stderr");
            if not labelled
                or not found(
                    "" if missing(stderr) else stderr.toString(), "could not add label", "i"
                )
            {
                reportGhFailure(err, title, body, url);
                return;
            }
        }
    }
    globalThis.console.log("\n✓ Feedback submitted successfully!");
    globalThis.console.log(f"Issue URL: {issueUrl}\n");
    if not labelled {
        globalThis.console.log(
            "Note: created without the 'feedback' label because the repository does not define it.\n",
        );
    }
}

def:priv handleFallback(title: str, body: str, url: str, missingGh: bool) {
    globalThis.console.log(
        "⚠️  GitHub CLI not found. Manual submission required."
            if missingGh
            else "⚠️  GitHub authentication required. Manual submission required.",
    );
    showManual(title, body, url);
    if not missingGh {
        globalThis.console.log("\nTo auto-submit in the future: gh auth login");
    }
    process.exit(0);
}

obj FeedbackCommand(globalThis.Object) {
    async def execute(message: str, options: any = None) {
        details = at(options, "body");
        title = formatTitle(message);
        body = formatBody(message, details);
        url = "https://github.com/Fission-AI/OpenSpec/issues/new?"
            + new(
                globalThis.URLSearchParams,
                rec(
                    template="bug_report.yml",
                    title=title,
                    what_happened=f"{message}\n\n{details}" if details else message,
                    version=getVersion(),
                    environment=f"{os.platform()}, Node {process.version}",
                ),
            ).toString();
        if not ghRuns("where" if process.platform == "win32" else "which", ["gh"]) {
            handleFallback(title, body, url, True);
        } elif not ghRuns("gh", ["auth", "status"]) {
            handleFallback(title, body, url, False);
        } else {
            submitViaGhCli(title, body, url);
        }
    }
}
