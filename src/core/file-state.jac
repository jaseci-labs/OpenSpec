import from "node:fs" { promises as fs }
import from "node:path" { dirname, basename, join }
import from "node:crypto" { randomUUID }
import from "node:process" { default as process }
import from "node:timers/promises" { setTimeout as sleep }

glob:priv LOCK_DEADLINE_MS: int = 5000,
          LOCK_POLL_MS: int = 25,
          PRIVATE_FILE_MODE: int = 0o600,
          lockOwnership: any = new(globalThis.WeakMap);

def:priv ignore(error: any) {}

def makeLockErrorFactory(data: any) -> any {
    def make(kind: str, info: any) -> any {
        if kind == "create-failed" {
            cause = info.cause;
            return StoreError(
                f"Cannot create {data.createSubject} {info.lockPath} ({at(cause, 'code') ?? cause}).",
                data.code,
                rec(target=data.target, fix=f"Check permissions on {dirname(info.lockPath)}."),
            );
        }
        return StoreError(
            data.busyMessage,
            data.code,
            rec(
                target=data.target,
                fix=f"Retry shortly; if this persists, delete the stale lock file {info.lockPath}.",
            ),
        );
    }
    return make;
}

def isNodeErrorCode(error: any, code: str) -> bool {
    return at(error, "code") == code;
}

async def pathIsFile(filePath: str) -> bool {
    try {
        return (await fs.stat(filePath)).isFile();
    } except Exception {
        return False;
    }
}

async def pathIsDirectory(dirPath: str) -> bool {
    try {
        return (await fs.stat(dirPath)).isDirectory();
    } except Exception {
        return False;
    }
}

async def writeFileAtomically(filePath: str, content: str) {
    dirPath = dirname(filePath);
    await FileSystemUtils.createDirectory(dirPath);
    suffix: str = globalThis.Math.random().toString(36).slice(2);
    tempPath = join(
        dirPath, f".{basename(filePath)}.{process.pid}.{globalThis.Date.now()}.{suffix}.tmp"
    );
    try {
        await fs.writeFile(tempPath, content, rec(encoding="utf-8", mode=PRIVATE_FILE_MODE));
        await fs.rename(tempPath, filePath);
    } except Exception {
        await fs.rm(tempPath, rec(force=True)).catch(ignore);
        raise;
    }
}

async def:priv openLock(lockPath: str) -> any {
    lock = await fs.open(lockPath, "wx", PRIVATE_FILE_MODE);
    token = f"{process.pid}:{randomUUID()}";
    try {
        await lock.writeFile(token, "utf-8");
        try {
            await lock.sync();
        } except Exception as e {
            if at(js_error(e), "code") not in ["EINVAL", "ENOTSUP", "ENOSYS"] {
                raise;
            }
        }
    } except Exception {
        await lock.close().catch(ignore);
        await fs.rm(lockPath, rec(force=True)).catch(ignore);
        raise;
    }
    lockOwnership.set(lock, token);
    return lock;
}

async def acquireFileLock(options: any) -> any {
    lockPath: str = options.lockPath;
    errorFor: any = options.errorFor;
    lockDir = dirname(lockPath);
    await FileSystemUtils.createDirectory(lockDir);
    if not await FileSystemUtils.canWriteFile(lockDir) {
        raise errorFor("create-failed", rec(lockPath=lockPath, cause="EACCES"));
    }
    deadline = globalThis.Date.now() + LOCK_DEADLINE_MS;
    while True {
        try {
            return await openLock(lockPath);
        } except Exception as e {
            error = js_error(e);
            if not isNodeErrorCode(error, "EEXIST") {
                raise errorFor("create-failed", rec(lockPath=lockPath, cause=error));
            }
            if globalThis.Date.now() >= deadline {
                raise errorFor("timeout", rec(lockPath=lockPath));
            }
            await sleep(LOCK_POLL_MS);
        }
    }
}

async def releaseFileLock(lock: any, lockPath: str) {
    token = lockOwnership.get(lock);
    lockOwnership.delete(lock);
    await lock.close().catch(ignore);
    if token is None {
        return;
    }
    try {
        if await fs.readFile(lockPath, "utf-8") == token {
            await fs.rm(lockPath, rec(force=True));
        }
    } except Exception {}
}
