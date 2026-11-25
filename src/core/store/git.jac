import from "node:child_process" { execFile }
import from "node:fs" { promises as fs }
import from "node:path" { join }
import from "node:process" { default as process }
import from "node:util" { promisify }

glob GIT_EXEC_OPTIONS: any = rec(
         encoding="utf8", timeout=15000, killSignal="SIGKILL", maxBuffer=16 * 1024 * 1024
     ),
     GIT_WRITE_EXEC_OPTIONS: any = rec(encoding="utf8", timeout=120000, maxBuffer=16 * 1024 * 1024),
     GIT_REPO_LOCATION_ENV_VARS: list[str] = [
         "GIT_DIR",
         "GIT_WORK_TREE",
         "GIT_INDEX_FILE",
         "GIT_OBJECT_DIRECTORY",
         "GIT_ALTERNATE_OBJECT_DIRECTORIES",
         "GIT_COMMON_DIR",
     ];

glob:priv run: any = promisify(execFile),
          NO_INIT_FIX: str = "Install Git or rerun setup with --no-init-git.";

def:priv probe(args: list[str], options: any = None) -> any {
    return run("git", args, merge(GIT_EXEC_OPTIONS, options));
}

def:priv write(args: list[str], cwd: str) -> any {
    return run("git", args, merge(GIT_WRITE_EXEC_OPTIONS, rec(cwd=cwd)));
}

def:priv fail(message: str, code: str, fix: str) -> StoreError {
    return StoreError(message, code, rec(target="store.git", fix=fix));
}

def:priv reason(e: any) -> str {
    err = js_error(e);
    return err.message if isinstance(err, globalThis.Error) else globalThis.String(err);
}

async def isGitRepositoryAtRoot(storeRoot: str) -> bool {
    try {
        stat = await fs.stat(join(storeRoot, ".git"));
        return stat.isDirectory() or stat.isFile();
    } except Exception {
        return False;
    }
}

async def initGitRepository(storeRoot: str) -> bool {
    if await isGitRepositoryAtRoot(storeRoot) {
        return False;
    }
    try {
        await write(["init"], storeRoot);
    } except Exception as e {
        raise fail(
            f"Failed to initialize Git repository: {reason(e)}",
            "store_git_init_failed",
            NO_INIT_FIX,
        );
    }
    return True;
}

async def assertGitCommitIdentity(probeCwd: str) {
    for ident in ["GIT_COMMITTER_IDENT", "GIT_AUTHOR_IDENT"] {
        try {
            await probe(["var", ident], rec(cwd=probeCwd));
        } except Exception as e {
            if at(js_error(e), "code") == "ENOENT" {
                raise fail(
                    "Git is not available, so setup cannot create the initial store commit.",
                    "store_git_init_failed",
                    NO_INIT_FIX,
                );
            }
            raise fail(
                "No usable Git commit identity is configured, so setup cannot create the initial store commit.",
                "store_git_identity_missing",
                'Run git config --global user.name "Your Name" and git config --global user.email "you@example.com", or rerun setup with --no-init-git.',
            );
        }
    }
}

async def commitStoreFiles(storeRoot: str, id: str, pathspecs: list[str]) -> bool {
    if not pathspecs {
        return False;
    }
    try {
        await write(["add", "--", *pathspecs], storeRoot);
        await write(
            ["commit", "-m", f"Initialize OpenSpec store {id}", "--", *pathspecs], storeRoot
        );
    } except Exception as e {
        await write(["rm", "--cached", "-r", "-f", "-q", "--", *pathspecs], storeRoot).catch(
            lambda (ignored: any) -> any { None }
        );
        raise fail(
            f"Failed to create the initial store commit: {reason(e)}",
            "store_git_commit_failed",
            "Commit the created files manually, or rerun setup with --no-init-git.",
        );
    }
    return True;
}

def isProbeResourceFailure(error: any) -> bool {
    if kind(error) != "object" or error is JsNull {
        return False;
    }
    return error["code"] in ["ERR_CHILD_PROCESS_STDIO_MAXBUFFER", "ETIMEDOUT"]
        or (same(error["killed"], True) and error["signal"] == "SIGKILL");
}

async def:priv gitProbe(storeRoot: str, args: list[str], options: any = None) -> any {
    try {
        return (await probe(["-C", storeRoot, *args], options)).stdout;
    } except Exception as e {
        if isProbeResourceFailure(js_error(e)) {
            process.emitWarning(
                f"git {' '.join(args)} did not complete in {storeRoot}; store Git facts are unavailable for this run.",
                "OpenSpecGitProbeWarning",
            );
        }
        return JsNull;
    }
}

async def:priv hasOutput(storeRoot: str, args: list[str]) -> any {
    stdout = await gitProbe(storeRoot, args);
    return JsNull if stdout is JsNull else stdout.trim() != "";
}

async def gitHasCommits(storeRoot: str) -> any {
    try {
        await probe(["-C", storeRoot, "rev-parse", "--verify", "--quiet", "HEAD"]);
        return True;
    } except Exception as e {
        return False if same(at(js_error(e), "code"), 1) else JsNull;
    }
}

async def gitHasUncommittedChanges(storeRoot: str) -> any {
    return await hasOutput(storeRoot, ["status", "--porcelain"]);
}

async def gitHasRemote(storeRoot: str) -> any {
    return await hasOutput(storeRoot, ["remote"]);
}

async def gitDirectoryHasTrackedFiles(storeRoot: str, relativeDir: str) -> any {
    return await hasOutput(storeRoot, ["ls-files", "--", relativeDir]);
}

def envWithoutGitRepoLocation(env: any = None) -> any {
    clean = merge(process.env if env is None else env);
    for key in GIT_REPO_LOCATION_ENV_VARS {
        globalThis.Reflect.deleteProperty(clean, key);
    }
    return clean;
}

async def gitOriginUrl(storeRoot: str) -> any {
    stdout = await gitProbe(
        storeRoot, ["remote", "get-url", "origin"], rec(env=envWithoutGitRepoLocation())
    );
    return JsNull if stdout is JsNull else (stdout.trim() or JsNull);
}

def repoNameFromGitUrl(url: any) -> any {
    cleaned = sub(url.trim(), "\\.git\\/?$", "", "i");
    urlLike = matchOf(cleaned, "^[a-z][a-z0-9+.-]*:\\/\\/[^/]+(?:\\/(.*))?$", "i");
    path: any = urlLike[1]
        if urlLike
        else at(matchOf(cleaned, "^(?:[\\w.-]+@)?[\\w.-]+:(.+)$"), "1");
    segments = [s for s in path.split("/") if s] if path else [];
    return segments[-1] if segments and segments[-1] not in [".", ".."] else JsNull;
}

async def gitTrackingDrift(storeRoot: str) -> any {
    stdout = await gitProbe(
        storeRoot, ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"]
    );
    m = JsNull if stdout is JsNull else matchOf(stdout.trim(), "^(\\d+)\\s+(\\d+)$");
    return rec(behind=globalThis.Number(m[1]), ahead=globalThis.Number(m[2])) if m else JsNull;
}
