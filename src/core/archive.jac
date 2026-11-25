import from "fs" { constants, createReadStream, promises as fs }
import from "node:crypto" { createHash, randomUUID }
import from "path" { default as path }
import from "node:process" { default as process }

type ArchiveOptions = any;

glob:priv chalk: any = pick("chalk"),
          COUNT_KEYS: list[str] = ["added", "modified", "removed", "renamed"],
          CONCURRENT: str = "Archive rollback would overwrite a concurrent change at ",
          modeBits: any = new(globalThis.Function, "s", "return (s.mode & 0o7777n).toString()"),
          streamDigest: any = new(
              globalThis.Function,
              "createHash",
              "createReadStream",
              "return async (p) => { const h = createHash('sha256'); for await (const c of createReadStream(p)) h.update(c); return h.digest(); }",
          )(createHash, createReadStream),
          BIG: any = rec(bigint=True);

obj ArchiveBlockedError(globalThis.Error) {
    def init(code: str, message: str, fix: any = None) {
        super.init(message);
        self.name = "ArchiveBlockedError";
        self.diagnostic = merge(
            rec(severity="error", code=code, message=message), rec(fix=fix) if fix else None
        );
    }
}

obj MoveDestinationRetainedError(globalThis.Error) {
    def init(message: str) {
        super.init(message);
    }
}

obj RetirementCleanupError(globalThis.Error) {
    def init(message: str) {
        super.init(message);
    }
}

def:priv fail(message: str) {
    raise new(globalThis.Error, message);
}

def:priv messageOf(error: any) -> str {
    err = js_error(error);
    return err.message if isinstance(err, globalThis.Error) else globalThis.String(err);
}

def:priv codeOf(error: any) -> any {
    return at(js_error(error), "code");
}

def:priv rethrowUnless(error: any, code: str) {
    if codeOf(error) != code {
        raise js_error(error);
    }
}

def:priv blockedExists(name: str) -> any {
    return ArchiveBlockedError("archive_target_exists", f"Archive '{name}' already exists.");
}

def:priv sha256(data: any) -> str {
    return createHash("sha256").update(data).digest("hex");
}

def:priv clean(text: any) -> str {
    return sub(text, "[\\u0000-\\u001f\\u007f]", "?");
}

def:priv statIdentity(v: any, keys: any = None) -> str {
    return ":".join([
        globalThis.String(v[k])
        for k in (keys or ["dev", "ino", "mode", "size", "mtimeNs", "ctimeNs"])
    ]);
}

def:priv movableStatIdentity(v: any) -> str {
    return statIdentity(v, ["dev", "ino", "mode", "size"]);
}

async def isRetirableSpec(specName: str, rebuilt: str) -> bool {
    verdict = await Validator().validateSpecContent(specName, rebuilt);
    if verdict.valid {
        return False;
    }
    errors = [i for i in verdict.issues if i.level == "ERROR"];
    return len(errors) > 0
        and len([i for i in errors if i.message != VALIDATION_MESSAGES.SPEC_NO_REQUIREMENTS]) == 0;
}

def:priv describeUnaccountedContent(lines: any) -> str {
    shown: list[str] = [];
    for line in lines[:3] {
        safe = globalThis.Array.from(clean(line));
        clipped = "".join(safe[:200]);
        shown.append(f'"{clipped}…"' if len(safe) > 200 else f'"{clipped}"');
    }
    rest = f", and {len(lines) - 3} more line(s)" if len(lines) > 3 else "";
    return ", ".join(shown) + rest;
}

async def:priv decideSpecOutcome(
    update: any, built: any, skipValidation: bool, retirementDeclared: bool
) -> str {
    if not retirementDeclared
        or skipValidation
        or not built.noRequirementBlocks
        or len(built.unaccountedContent) != 0
    {
        return "write";
    }
    if not await isRetirableSpec(update.id, built.rebuilt) {
        return "write";
    }
    if not update.exists {
        return "skip";
    }
    return "retire" if built.counts.removed > 0 else "write";
}

async def:priv listActiveChangeNames(changesDir: str) -> any {
    try {
        entries = await fs.readdir(changesDir, rec(withFileTypes=True));
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        return [];
    }
    return globalThis.Array.prototype.sort.call([
        e.name
        for e in entries
        if e.isDirectory() and e.name != "archive"
    ]);
}

def:priv quoteForShell(value: str) -> any {
    if found(value, "^[A-Za-z0-9._\\/-]+$") {
        return value;
    }
    return None if found(value, "[\"\\\\$`\\r\\n%!]") else f'"{value}"';
}

def:priv rerunFlags(options: any) -> str {
    flags = ["--skip-specs"] if at(options, "skipSpecs") else [];
    if skipsValidation(options) {
        flags.append("--no-validate");
    }
    flags.append("--yes");
    return " ".join(flags);
}

def:priv skipsValidation(options: any) -> bool {
    return at(options, "validate") is False or at(options, "noValidate") is True;
}

def:priv rerunCommand(home: any, changeName: any, options: any) -> str {
    flags = rerunFlags(options);
    quoted = quoteForShell(changeName) ?? "<change-name>";
    if changeName.startsWith("-") {
        return f"{withStoreFlag(home, f'openspec archive {flags}')} -- {quoted}";
    }
    return withStoreFlag(home, f"openspec archive {quoted} {flags}");
}

async def:priv confirmOrBlock(message: str, answer: bool, blocked: any) -> bool {
    try {
        return await globalThis.Reflect.apply(
            confirmPrompt, None, [rec(message=message, **{"default": answer})]
        );
    } except Exception as e {
        if isNonInteractivePromptError(js_error(e)) {
            raise blocked();
        }
        raise js_error(e);
    }
}

def:priv toArchiveDiagnostic(error: any) -> any {
    err = js_error(error);
    if isinstance(err, ArchiveBlockedError) or isRootSelectionError(err) {
        return err.diagnostic;
    }
    if isinstance(err, RetirementCleanupError) {
        return rec(
            severity="error",
            code="archive_retirement_cleanup_failed",
            message=err.message,
            fix="Inspect the archived change and all recovery paths in this diagnostic; preserve any needed content before cleanup.",
        );
    }
    return rec(severity="error", code="archive_error", message=messageOf(err));
}

async def:priv copySymbolicLink(src: str, dest: str) {
    target = await fs.readlink(src);
    windowsDir = process.platform == "win32" and (await fs.stat(src)).isDirectory();
    await fs.symlink(
        path.resolve(path.dirname(src), target)
            if windowsDir and not path.isAbsolute(target)
            else target,
        dest,
        "junction" if windowsDir else None,
    );
}

async def:priv copyDirContents(src: str, dest: str) {
    sourceStat = await fs.lstat(src);
    await fs.chmod(dest, (sourceStat.mode & 0o7777) | 0o700);
    for item in await fs.readdir(src, rec(withFileTypes=True)) {
        srcPath = path.join(src, item.name);
        destPath = path.join(dest, item.name);
        if item.isDirectory() {
            await fs.mkdir(destPath, rec(mode=0o700));
            await copyDirContents(srcPath, destPath);
        } elif item.isSymbolicLink() {
            await copySymbolicLink(srcPath, destPath);
        } elif item.isFile() {
            await fs.copyFile(srcPath, destPath, constants.COPYFILE_EXCL);
        } else {
            fail(f"Cannot archive unsupported filesystem entry: {srcPath}");
        }
    }
    await fs.chmod(dest, sourceStat.mode & 0o7777);
}

def:priv hashField(hash: any, label: str, value: any) {
    labelBuffer = globalThis.Buffer.from(label);
    valueBuffer = globalThis.Buffer.from(value) if kind(value) == "string" else value;
    lengths = globalThis.Buffer.allocUnsafe(16);
    lengths.writeBigUInt64BE(globalThis.BigInt(labelBuffer.length), 0);
    lengths.writeBigUInt64BE(globalThis.BigInt(valueBuffer.length), 8);
    hash.update(lengths);
    hash.update(labelBuffer);
    hash.update(valueBuffer);
}

async def:priv assertSameStat(entryPath: str, before: any, what: str = "Path") {
    if statIdentity(before) != statIdentity(await fs.lstat(entryPath, BIG)) {
        fail(f"{what} changed while archive was reading {entryPath}.");
    }
}

async def:priv fingerprintDirectoryContents(top: str) -> str {
    hash = createHash("sha256");
    async def walk(dir: str, relativeDir: str) {
        before = await fs.lstat(dir, BIG);
        if not before.isDirectory() {
            fail(f"Expected a directory while verifying {dir}.");
        }
        hashField(hash, "directory-mode", modeBits(before));
        entries = globalThis.Array.prototype.sort.call(
            await fs.readdir(dir, rec(withFileTypes=True)),
            lambda (a: any, b: any) -> int {
                -1 if a.name < b.name else (1 if a.name > b.name else 0)
            },
        );
        for item in entries {
            entryPath = path.join(dir, item.name);
            relativePath = path.join(relativeDir, item.name);
            stat = await fs.lstat(entryPath, BIG);
            hashField(hash, "path", relativePath);
            if stat.isDirectory() {
                hashField(hash, "type", "directory");
                await walk(entryPath, relativePath);
            } elif stat.isSymbolicLink() {
                target = await fs.readlink(entryPath);
                await assertSameStat(entryPath, stat);
                hashField(hash, "type", "symlink");
                hashField(hash, "target", target);
            } elif stat.isFile() {
                content = await streamDigest(entryPath);
                await assertSameStat(entryPath, stat);
                hashField(hash, "type", "file");
                hashField(hash, "mode", modeBits(stat));
                hashField(hash, "content-sha256", content);
            } else {
                hashField(hash, "type", "other");
                hashField(hash, "mode", globalThis.String(stat.mode));
                hashField(hash, "size", globalThis.String(stat.size));
            }
        }
        await assertSameStat(dir, before, "Directory");
    }
    await walk(top, "");
    return hash.digest("hex");
}

async def:priv assertCopiedDirectoryUnchanged(stagedSource: str, destination: str, expected: str) {
    source = await fingerprintDirectoryContents(stagedSource);
    copied = await fingerprintDirectoryContents(destination);
    if source != expected or copied != expected {
        fail(
            f"Change directory contents changed during the fallback copy from {stagedSource} to {destination}.",
        );
    }
}

def:priv isFallbackRenameCode(code: any) -> bool {
    return code in ["EPERM", "EXDEV"];
}

async def:priv listTreeEntriesDeepestFirst(top: str) -> list[any] {
    entries: list[any] = [];
    async def walk(dir: str, relativeDir: str) {
        for item in await fs.readdir(dir, rec(withFileTypes=True)) {
            relative = item.name if relativeDir == "" else path.join(relativeDir, item.name);
            if item.isDirectory() {
                await walk(path.join(dir, item.name), relative);
                entries.append(rec(relative=relative, kind="directory"));
            } else {
                entries.append(
                    rec(relative=relative, kind="symlink" if item.isSymbolicLink() else "file")
                );
            }
        }
    }
    await walk(top, "");
    return entries;
}

def:priv makeClaimSuffix(entries: list[any]) -> str {
    while True {
        suffix = f".openspec-claim-{randomUUID()}";
        clash = False;
        for item in entries {
            if item.relative.endswith(suffix) {
                clash = True;
            }
        }
        if not clash {
            return suffix;
        }
    }
}

async def:priv readEntryIdentity(entryPath: str, entryKind: str) -> str {
    if entryKind == "symlink" {
        return f"symlink:{await fs.readlink(entryPath)}";
    }
    return f"file:{(await streamDigest(entryPath)).toString('hex')}";
}

async def:priv putBack(claimed: str, target: str) {
    await fs.rename(claimed, target).catch(lambda (e: any) -> any { None });
}

async def:priv removeVerifiedTree(top: str, entries: list[any], destination: str) {
    claimSuffix = makeClaimSuffix(entries);
    for item in entries {
        target = path.join(top, item.relative);
        if item.kind == "directory" {
            await fs.rmdir(target);
            continue;
        }
        claimed = target + claimSuffix;
        await fs.rename(target, claimed);
        try {
            claimedIdentity = await readEntryIdentity(claimed, item.kind);
            copiedIdentity = await readEntryIdentity(
                path.join(destination, item.relative), item.kind
            );
        } except Exception as e {
            await putBack(claimed, target);
            raise js_error(e);
        }
        if claimedIdentity != copiedIdentity {
            await putBack(claimed, target);
            fail(
                f"{target} changed after it was verified, so the copy at {destination} does not hold its current content.",
            );
        }
        await fs.rm(claimed, rec(force=True));
    }
    await fs.rmdir(top);
}

async def:priv restoreOrExplain(error: any, source: str, restoreSource: any) {
    if restoreSource is not None {
        try {
            await restoreSource();
        } except Exception as restoreError {
            fail(
                f"{messageOf(error)} Could not restore the staged source at {source} ({messageOf(restoreError)}).",
            );
        }
    }
}

async def:priv dropDir(dest: str) {
    await fs.rm(dest, rec(recursive=True, force=True)).catch(lambda (e: any) -> any { None });
}

async def:priv copyThenRemoveDirectory(
    source: str, dest: str, options: any, restoreSource: any = None
) {
    verify = at(options, "verifyCopiedDestination");
    destIsOurs = False;
    try {
        sourceFingerprint = await fingerprintDirectoryContents(source);
        await fs.mkdir(dest, rec(mode=0o700));
        destIsOurs = True;
        await copyDirContents(source, dest);
        if verify is not None {
            await verify(source);
        }
        await assertCopiedDirectoryUnchanged(source, dest, sourceFingerprint);
    } except Exception as copyError {
        if destIsOurs {
            await dropDir(dest);
        }
        await restoreOrExplain(copyError, source, restoreSource);
        if codeOf(copyError) == "EEXIST" {
            raise blockedExists(path.basename(dest));
        }
        raise js_error(copyError);
    }
    try {
        verifiedEntries = await listTreeEntriesDeepestFirst(source);
        if verify is not None {
            await verify(source);
        }
        await assertCopiedDirectoryUnchanged(source, dest, sourceFingerprint);
    } except Exception as verificationError {
        await dropDir(dest);
        await restoreOrExplain(verificationError, source, restoreSource);
        raise js_error(verificationError);
    }
    try {
        await removeVerifiedTree(source, verifiedEntries, dest);
    } except Exception as cleanupError {
        raise MoveDestinationRetainedError(
            f"Copied {source} to {dest}, but could not remove the source at {source} completely ({messageOf(cleanupError)}). The complete destination was retained for recovery.",
        );
    }
}

async def:priv moveDirectory(src: str, dest: str, options: any = None) {
    try {
        await fs.rename(src, dest);
        return;
    } except Exception as err {
        code = codeOf(err);
        if code in ["ENOTEMPTY", "EEXIST"] {
            raise blockedExists(path.basename(dest));
        }
        if not isFallbackRenameCode(code) {
            raise js_error(err);
        }
    }
    stagedSource = path.join(path.dirname(src), f".openspec-move-{randomUUID()}");
    try {
        await fs.rename(src, stagedSource);
    } except Exception as stageError {
        if isFallbackRenameCode(codeOf(stageError)) {
            await copyThenRemoveDirectory(src, dest, options);
            return;
        }
        fail(
            f"Could not safely stage {src} before the fallback archive copy ({messageOf(stageError)}). No fallback copy was attempted.",
        );
    }
    async def restore {
        await fs.rename(stagedSource, src);
    }
    await copyThenRemoveDirectory(stagedSource, dest, options, restore);
}

async def:priv assertArchiveDestinationAvailable(archivePath: str, archiveName: str) {
    try {
        await fs.lstat(archivePath);
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        return;
    }
    raise blockedExists(archiveName);
}

def:priv archiveClaimPath(archivePath: str) -> str {
    return path.join(path.dirname(archivePath), ".openspec-archive.lock");
}

def:priv isSameArchiveClaimFile(first: any, second: any) -> bool {
    zero = globalThis.BigInt(0);
    return same(first.ino, second.ino)
        and (same(first.dev, second.dev) or same(first.dev, zero) or same(second.dev, zero));
}

async def:priv releaseArchiveClaim(claim: any, claimPath: str) {
    owned = await claim.handle.stat(BIG).catch(lambda (e: any) -> any { None });
    await claim.handle.close().catch(lambda (e: any) -> any { None });
    if owned is None {
        return;
    }
    try {
        current = await fs.lstat(claimPath, BIG);
        contents = await fs.readFile(claimPath, "utf8");
        currentAfterRead = await fs.lstat(claimPath, BIG);
        if isSameArchiveClaimFile(current, owned)
            and isSameArchiveClaimFile(current, currentAfterRead)
            and contents == claim.contents
        {
            await fs.unlink(claimPath);
        }
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
    }
}

async def:priv claimArchiveDestination(archivePath: str, archiveName: str) -> any {
    claimPath = archiveClaimPath(archivePath);
    try {
        handle = await fs.open(claimPath, "wx");
        claim = rec(
            handle=handle,
            contents=globalThis.JSON.stringify(rec(pid=process.pid, nonce=randomUUID())),
        );
        try {
            await handle.writeFile(claim.contents);
            await handle.sync();
            return claim;
        } except Exception as e {
            await promise(releaseArchiveClaim(claim, claimPath)).catch(
                lambda (x: any) -> any { None }
            );
            raise js_error(e);
        }
    } except Exception as e {
        if codeOf(e) == "EEXIST" {
            raise ArchiveBlockedError(
                "archive_target_exists",
                f"Archive '{archiveName}' is already being created. If no archive process is running, remove the stale claim at {claimPath} and rerun.",
            );
        }
        raise js_error(e);
    }
}

async def:priv fingerprintPath(filePath: str) -> str {
    try {
        stat = await fs.lstat(filePath, BIG);
        if stat.isSymbolicLink() {
            link = await fs.readlink(filePath);
            try {
                referentBefore = await fs.stat(filePath, BIG);
                hash = sha256(await fs.readFile(filePath));
                referentAfter = await fs.stat(filePath, BIG);
                entryAfter = await fs.lstat(filePath, BIG);
                if statIdentity(stat) != statIdentity(entryAfter)
                    or statIdentity(referentBefore) != statIdentity(referentAfter)
                    or link != await fs.readlink(filePath)
                {
                    fail(f"Path changed while archive was reading {filePath}.");
                }
                return f"symlink:{statIdentity(stat)}:{link}:{statIdentity(referentAfter)}:{hash}";
            } except Exception as e {
                if codeOf(e) == "ENOENT" {
                    return f"symlink:{statIdentity(stat)}:{link}:missing";
                }
                raise js_error(e);
            }
        }
        if stat.isFile() {
            hash = sha256(await fs.readFile(filePath));
            after = await fs.lstat(filePath, BIG);
            if statIdentity(stat) != statIdentity(after) {
                fail(f"Path changed while archive was reading {filePath}.");
            }
            return f"file:{statIdentity(after)}:{hash}";
        }
        return f"other:{statIdentity(stat)}";
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        return "missing";
    }
}

async def:priv fingerprintMovablePath(filePath: str) -> str {
    try {
        item = await fs.lstat(filePath, BIG);
        hash = sha256(await fs.readFile(filePath));
        if item.isSymbolicLink() {
            link = await fs.readlink(filePath);
            referent = await fs.stat(filePath, BIG);
            entryAfter = await fs.lstat(filePath, BIG);
            referentAfter = await fs.stat(filePath, BIG);
            linkAfter = await fs.readlink(filePath);
            if statIdentity(item) != statIdentity(entryAfter)
                or statIdentity(referent) != statIdentity(referentAfter)
                or link != linkAfter
            {
                fail(f"Path changed while archive was reading {filePath}.");
            }
            return f"symlink:{movableStatIdentity(item)}:{link}:{movableStatIdentity(referentAfter)}:{hash}";
        }
        await assertSameStat(filePath, item);
        return f"file:{movableStatIdentity(item)}:{hash}";
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        return "missing";
    }
}

async def:priv fingerprintPortableContent(filePath: str) -> str {
    try {
        item = await fs.lstat(filePath);
        hash = sha256(await fs.readFile(filePath));
        if item.isSymbolicLink() {
            return f"symlink:{await fs.readlink(filePath)}:{hash}";
        }
        return f"file:{hash}";
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        return "missing";
    }
}

async def:priv assertRetirementAuthorization(
    changeDir: str, expected: str, verifyMarker: bool = True
) {
    metadataPath = path.join(changeDir, METADATA_FILENAME);
    before = await fingerprintPortableContent(metadataPath);
    stillDeclared = not verifyMarker or readRetireCapabilitiesMarker(changeDir).declared;
    after = await fingerprintPortableContent(metadataPath);
    if before != expected or after != expected or not stillDeclared {
        fail(
            f"The {METADATA_FILENAME} retirement authorization changed before archive could complete.",
        );
    }
}

async def:priv fingerprintSpecInputs(update: any) -> str {
    return f"{await fingerprintPath(update.source)}\n{await fingerprintPath(update.target)}";
}

async def:priv mutationTargetIdentity(mutation: any) -> str {
    target = mutation.update.target;
    try {
        stat = await fs.stat(target, BIG);
        return f"{globalThis.String(stat.dev)}:{globalThis.String(stat.ino)}";
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        parent = path.dirname(target);
        realParent = await fs.realpath(parent).catch(
            lambda (x: any) -> any { path.resolve(parent) }
        );
        return f"missing:{path.join(realParent, path.basename(target))}";
    }
}

async def:priv assertDistinctMutationTargets(mutations: list[any]) {
    owners: dict[str, str] = {};
    for mutation in mutations {
        identity = await mutationTargetIdentity(mutation);
        if identity in owners {
            fail(
                f"Spec updates for '{owners[identity]}' and '{mutation.update.id}' resolve to the same target {identity}. Replace the capability alias or combine the deltas before archiving.",
            );
        }
        owners[identity] = mutation.update.id;
    }
}

async def:priv deepestExistingAncestor(dir: str, boundaryDir: str) -> str {
    current = dir;
    while True {
        if current == boundaryDir or not current.startswith(boundaryDir + path.sep) {
            return boundaryDir;
        }
        try {
            await fs.lstat(current);
            return current;
        } except Exception as e {
            rethrowUnless(e, "ENOENT");
        }
        current = path.dirname(current);
    }
}

async def:priv captureSnapshot(mutation: any, mainSpecsDir: str) -> any {
    update = mutation.update;
    outcome = mutation.outcome;
    snapshot = rec(target=update.target, existed=True, outcome=outcome);
    expected = rec(expectedContent=globalThis.Buffer.from(mutation.rebuilt))
        if outcome == "write"
        else None;
    try {
        stat = await fs.lstat(update.target);
    } except Exception as e {
        rethrowUnless(e, "ENOENT");
        snapshot.existed = False;
        snapshot.pruneBoundary = await deepestExistingAncestor(
            path.dirname(update.target), mainSpecsDir
        );
        return merge(snapshot, expected);
    }
    if stat.isSymbolicLink() {
        content: any = None;
        contentExisted = False;
        if outcome == "write" {
            try {
                content = await fs.readFile(update.target);
                contentExisted = True;
            } except Exception as e {
                rethrowUnless(e, "ENOENT");
            }
        }
        return merge(
            snapshot,
            expected,
            rec(
                content=content,
                contentExisted=contentExisted,
                symlink=await fs.readlink(update.target),
            ),
        );
    }
    if stat.isFile() {
        return merge(
            snapshot, expected, rec(content=await fs.readFile(update.target), mode=stat.mode)
        );
    }
    return merge(snapshot, expected);
}

async def:priv captureSpecSnapshots(mutations: list[any], mainSpecsDir: str) -> any {
    return await globalThis.Promise.all([
        promise(captureSnapshot(m, mainSpecsDir))
        for m in mutations
    ]);
}

async def:priv restoreSnapshot(snapshot: any, mainSpecsDir: str) {
    target = snapshot.target;
    symlink = snapshot["symlink"];
    concurrent = f"{CONCURRENT}{target}.";
    if snapshot.outcome == "retire" {
        displaced = snapshot["displacedPath"];
        if displaced is not None {
            try {
                await fs.lstat(target);
                fail(f"{concurrent} The displaced spec was retained at {displaced}.");
            } except Exception as e {
                rethrowUnless(e, "ENOENT");
            }
            await fs.rename(displaced, target);
            snapshot.displacedPath = None;
            return;
        }
        try {
            current = await fs.lstat(target);
            if symlink is not None
                and current.isSymbolicLink()
                and (await fs.readlink(target)) == symlink
            {
                return;
            }
            if symlink is None
                and snapshot["content"] is not None
                and current.isFile()
                and (await fs.readFile(target)).equals(snapshot.content)
            {
                return;
            }
            fail(concurrent);
        } except Exception as e {
            rethrowUnless(e, "ENOENT");
        }
    } else {
        try {
            current = await fs.lstat(target);
        } except Exception as e {
            if codeOf(e) == "ENOENT" and not snapshot.existed {
                return;
            }
            raise js_error(e);
        }
        if symlink is not None {
            if not current.isSymbolicLink() or (await fs.readlink(target)) != symlink {
                fail(concurrent);
            }
        } elif not current.isFile()
            or (snapshot["mode"] is not None and current.mode != snapshot.mode)
        {
            fail(concurrent);
        }
        currentContent = await fs.readFile(target);
        original = None
            if symlink is not None and not snapshot["contentExisted"]
            else snapshot["content"];
        if original is not None and currentContent.equals(original) {
            return;
        }
        if snapshot["expectedContent"] is None
            or not currentContent.equals(snapshot.expectedContent)
        {
            fail(concurrent);
        }
    }
    if not snapshot.existed {
        await fs.rm(target, rec(force=True));
        await pruneEmptyDirs(path.dirname(target), snapshot["pruneBoundary"] ?? mainSpecsDir);
        return;
    }
    if symlink is not None {
        if snapshot.outcome == "retire" {
            await fs.mkdir(path.dirname(target), rec(recursive=True));
            await fs.symlink(symlink, target);
        } elif snapshot["contentExisted"] {
            await fs.writeFile(target, snapshot.content);
        } else {
            await fs.rm(path.resolve(path.dirname(target), symlink), rec(force=True));
        }
        return;
    }
    if snapshot["content"] is not None {
        await fs.mkdir(path.dirname(target), rec(recursive=True));
        await fs.writeFile(target, snapshot.content);
        if snapshot["mode"] is not None {
            await fs.chmod(target, snapshot.mode);
        }
    }
}

async def:priv restoreSpecSnapshots(snapshots: any, mainSpecsDir: str) {
    errors: list[str] = [];
    for i in range(len(snapshots) - 1, -1, -1) {
        try {
            await restoreSnapshot(snapshots[i], mainSpecsDir);
        } except Exception as e {
            errors.append(messageOf(e));
        }
    }
    if errors {
        fail(" ".join(errors));
    }
}

async def:priv finalizeRetirementBackups(snapshots: any, mainSpecsDir: str) {
    errors: list[str] = [];
    for snapshot in snapshots {
        displacedPath = snapshot["displacedPath"];
        if snapshot.outcome != "retire" or displacedPath is None {
            continue;
        }
        try {
            if snapshot["displacedFingerprint"] is None
                or (await fingerprintMovablePath(displacedPath)) != snapshot.displacedFingerprint
            {
                fail("the displaced spec changed after retirement verification");
            }
            await finalizeRetiredSpec(snapshot.target, displacedPath, mainSpecsDir);
            snapshot.displacedPath = None;
        } except Exception as e {
            errors.append(
                f"Could not finalize the retirement backup at {displacedPath} ({messageOf(e)})."
            );
        }
    }
    if errors {
        raise RetirementCleanupError(
            f"{' '.join(errors)} The change was archived, but retirement cleanup did not complete. Inspect all reported recovery paths before recovery or cleanup.",
        );
    }
}

def:priv printIssues(issues: any) {
    for issue in issues {
        if issue.level == "ERROR" {
            globalThis.console.log(chalk.red(f"  ✗ {issue.message}"));
        } elif issue.level == "WARNING" {
            globalThis.console.log(chalk.yellow(f"  ⚠ {issue.message}"));
        }
    }
}

def:priv addCounts(totals: any, counts: any) {
    for k in COUNT_KEYS {
        totals[k] = totals[k] + counts[k];
    }
}

async def:priv validateBeforeArchive(
    changeName: str, changeDir: str, home: any, json: bool
) -> bool {
    validator = Validator();
    if not json {
        changeFile = path.join(changeDir, "proposal.md");
        try {
            await fs.access(changeFile);
            changeReport = await validator.validateChange(changeFile);
            proposalIssues = [
                i
                for i in changeReport.issues
                if not found(i.path, "^deltas\\.\\d+\\.requirements?\\.")
            ];
            if not changeReport.valid and len(proposalIssues) > 0 {
                globalThis.console.log(
                    chalk.yellow("\nProposal warnings in proposal.md (non-blocking):")
                );
                for issue in proposalIssues {
                    symbol = "⚠" if issue.level in ["ERROR", "WARNING"] else "ℹ";
                    globalThis.console.log(chalk.yellow(f"  {symbol} {issue.message}"));
                }
            }
        } except Exception {}
    }
    changeSpecsDir = path.join(changeDir, "specs");
    rootSpecStat = await fs.stat(path.join(changeSpecsDir, "spec.md")).catch(
        lambda (e: any) -> any { JsNull }
    );
    hasDeltaSpecs = not missing(rootSpecStat) and rootSpecStat.isFile() == True;
    if not hasDeltaSpecs {
        hasDeltaSpecs = len(await findUnreadDeltaFiles(changeSpecsDir)) > 0;
    }
    if not hasDeltaSpecs {
        marker = readSkipSpecsMarker(changeDir);
        if marker["invalidReason"] {
            hasDeltaSpecs = True;
        } elif marker.declared {
            specsDirHasFiles = True;
            try {
                specsDirHasFiles = await hasAnyFileUnder(changeSpecsDir);
            } except Exception {}
            hasDeltaSpecs = specsDirHasFiles;
        }
    }
    if not hasDeltaSpecs {
        for spec in await discoverSpecFiles(changeSpecsDir) {
            try {
                content = await fs.readFile(spec.specFile, "utf-8");
                if found(content, "^##\\s+(ADDED|MODIFIED|REMOVED|RENAMED)\\s+Requirements", "im") {
                    hasDeltaSpecs = True;
                    break;
                }
            } except Exception {}
        }
    }
    if not hasDeltaSpecs {
        return True;
    }
    deltaReport = await validator.validateChangeDeltaSpecs(changeDir);
    if deltaReport.valid {
        return True;
    }
    if json {
        raise ArchiveBlockedError(
            "archive_validation_failed",
            f"Validation failed for change '{changeName}'.",
            f"Run {withStoreFlag(home, f'openspec validate {changeName}')} for details, fix the errors, or rerun with --no-validate.",
        );
    }
    globalThis.console.log(chalk.red("\nValidation errors in change delta specs:"));
    printIssues(deltaReport.issues);
    globalThis.console.log(
        chalk.red("\nValidation failed. Please fix the errors before archiving.")
    );
    globalThis.console.log(
        chalk.yellow("To skip validation (not recommended), use --no-validate flag.")
    );
    process.exitCode = 1;
    return False;
}

async def:priv recheckPrepared(
    prepared: list[any],
    changeDir: str,
    changeName: str,
    mainSpecsDir: str,
    retirementMarker: any,
    skipValidation: bool,
) {
    current = readRetireCapabilitiesMarker(changeDir);
    if current.declared != retirementMarker.declared
        or not same(current["invalidReason"], retirementMarker["invalidReason"])
    {
        fail(
            f"The {METADATA_FILENAME} retirement authorization changed while archive was awaiting confirmation.",
        );
    }
    currentUpdates = await findSpecUpdates(changeDir, mainSpecsDir);
    currentById: dict[str, any] = {u.id: u for u in currentUpdates};
    if len(currentUpdates) != len(prepared) {
        fail("The change specs changed while archive was awaiting confirmation.");
    }
    for proposed in prepared {
        id = proposed.update.id;
        if id not in currentById {
            fail(f"The delta for '{id}' changed while archive was awaiting confirmation.");
        }
        update = currentById[id];
        if (await fingerprintPath(update.source)) != proposed.sourceFingerprint
            or (await fingerprintPath(update.target)) != proposed.targetFingerprint
        {
            fail(
                f"Spec inputs for '{id}' changed while archive was awaiting confirmation. No files were changed; review the new content and rerun.",
            );
        }
        built = await buildUpdatedSpec(update, changeName, rec(silent=True));
        outcome = await decideSpecOutcome(update, built, skipValidation, retirementMarker.declared);
        if update.exists != proposed.update.exists
            or built.rebuilt != proposed.rebuilt
            or globalThis.JSON.stringify(built.counts) != globalThis.JSON.stringify(proposed.counts)
            or outcome != proposed.outcome
        {
            fail(
                f"Main spec '{id}' changed while archive was awaiting confirmation. No files were changed; review the new content and rerun.",
            );
        }
    }
}

async def:priv rebuiltSpecsValid(
    prepared: list[any], home: any, json: bool, retirementMarker: any
) -> bool {
    declared = retirementMarker.declared;
    reason = retirementMarker["invalidReason"];
    unhonored = f" The marker present now cannot be honored ({reason})." if reason else "";
    for p in prepared {
        if p.outcome != "write" {
            continue;
        }
        specName = p.update.id;
        verdict = await Validator().validateSpecContent(specName, p.rebuilt);
        if verdict.valid {
            continue;
        }
        emptiedByThisRun = False;
        if p.update.exists and p.counts.removed > 0 and p.noRequirementBlocks {
            emptiedByThisRun = await isRetirableSpec(specName, p.rebuilt);
        }
        unaccounted = len(p.unaccountedContent) > 0;
        retirementHint: any = None;
        blockedRetirementHint: any = None;
        refusalReason: any = None;
        if not declared and emptiedByThisRun and not unaccounted {
            retirementHint = f"This change removes the last requirement '{specName}' has. To retire the capability and delete its spec, add `retire_capabilities: true` to the change's {METADATA_FILENAME} (alongside its `schema:`, which that file requires), then rerun.{unhonored}";
        }
        if not declared and emptiedByThisRun and unaccounted {
            blockedRetirementHint = f"This change removes the last requirement '{specName}' has, so the rebuilt spec has none left and cannot be written. Retiring the capability is what archive does instead, and it is refused while the spec holds content the merge cannot safely account for and deleting the file would take with it: {describeUnaccountedContent(p.unaccountedContent)}. Move it into `## Purpose` or a canonical requirement, or delete the spec by hand, then rerun.{unhonored}";
        }
        if declared and unaccounted and await isRetirableSpec(specName, p.rebuilt) {
            refusalReason = f"'{specName}' declares retire_capabilities, but the spec holds content the merge cannot safely account for and deleting the file would take with it: {describeUnaccountedContent(p.unaccountedContent)}. Move it into `## Purpose` or a canonical requirement, or delete the spec by hand.";
        }
        if json {
            raise ArchiveBlockedError(
                "archive_spec_validation_failed",
                f"Rebuilt spec for '{specName}' failed validation. No files were changed.",
                refusalReason
                    or retirementHint
                    or blockedRetirementHint
                    or f"Run {withStoreFlag(home, f'openspec validate {specName}')} after fixing the change deltas.",
            );
        }
        globalThis.console.log(
            chalk.red(
                f"\nValidation errors in rebuilt spec for {specName} (will not write changes):"
            ),
        );
        printIssues(verdict.issues);
        for hint in [retirementHint, blockedRetirementHint, refusalReason] {
            if hint {
                globalThis.console.log(chalk.yellow(f"  → {hint}"));
            }
        }
        globalThis.console.log("Aborted. No files were changed.");
        process.exitCode = 1;
        return False;
    }
    return True;
}

def:priv retirementRecovery(home: any, unlinkedPath: str, realRoot: str) -> tuple[str, str] {
    relativeToRoot: str = path.relative(realRoot, unlinkedPath);
    insideRoot = relativeToRoot != ""
        and not relativeToRoot.startswith("..")
        and not path.isAbsolute(relativeToRoot);
    deletedPath = unlinkedPath
        if isStoreSelectedRoot(home) or not insideRoot
        else "/".join(relativeToRoot.split(path.sep));
    pasteable = None if path.isAbsolute(deletedPath) else quoteForShell(f":(top){deletedPath}");
    if pasteable {
        return (
            deletedPath,
            f"If it was committed, restore it with: git checkout HEAD -- {pasteable}",
        );
    }
    return (
        deletedPath,
        f"It was deleted from {deletedPath}; if it was committed, restore it from that checkout's history.",
    );
}

async def:priv runArchive(changeName: any, options: any, home: any, json: bool) -> any {
    log = globalThis.console.log;
    changesDir = home.changesDir;
    archiveDir = home.archiveDir;
    mainSpecsDir = home.specsDir;
    openspecDir = path.dirname(changesDir);
    for (allowed, managed, linkedLeaf) in [
        (home.path, openspecDir, True),
        (openspecDir, changesDir, True),
        (changesDir, archiveDir, False),
        (openspecDir, mainSpecsDir, True),
    ] {
        try {
            if linkedLeaf {
                FileSystemUtils.assertPathWithinAllowingLinkedLeaf(allowed, managed);
            } else {
                FileSystemUtils.assertPathWithin(allowed, managed);
            }
        } except Exception {
            raise ArchiveBlockedError(
                "archive_path_outside_root",
                f"Refusing to archive through a path outside the OpenSpec root: {managed}",
            );
        }
    }
    if not changeName {
        if json {
            raise ArchiveBlockedError(
                "archive_change_name_required",
                "A change name is required: archive --json is non-interactive.",
                withStoreFlag(home, "openspec archive <change-name> --json"),
            );
        }
        selected = await selectChange(changesDir, home, options);
        if missing(selected) or not selected {
            log("No change selected. Aborting.");
            return JsNull;
        }
        changeName = selected;
    }
    problem = folderStyleNameProblem(changeName, "Change name");
    if problem {
        raise ArchiveBlockedError("archive_change_name_invalid", problem);
    }
    changeDir = path.join(changesDir, changeName);
    try {
        stat = await fs.lstat(changeDir);
        if stat.isSymbolicLink() {
            raise ArchiveBlockedError(
                "archive_change_symlink",
                f"Change '{changeName}' is a symbolic link. Replace it with a real directory before archiving.",
            );
        }
        if not stat.isDirectory() {
            fail(f"Change '{changeName}' not found.");
        }
    } except Exception as e {
        if isinstance(js_error(e), ArchiveBlockedError) {
            raise js_error(e);
        }
        available = await listActiveChangeNames(changesDir);
        raise ArchiveBlockedError(
            "archive_change_not_found",
            f"Change '{changeName}' not found. Available changes: {', '.join(available)}"
                if len(available) > 0
                else f"Change '{changeName}' not found. No active changes exist in this root.",
        );
    }
    nested = await findNestedChangesIn(changesDir, changeName);
    if not missing(nested) {
        raise ArchiveBlockedError(
            "archive_change_is_namespace_folder",
            f"Cannot archive '{changeName}': {describeNestedChange(nested)}",
            f"Rename openspec/changes/{nested.nested[0]}/ to a flat change directory, then archive it.",
        );
    }
    unknownKeys = readUnknownChangeMetadataKeys(changeDir);
    unknownWarning = formatUnknownChangeMetadataKeysMessage(unknownKeys)
        if len(unknownKeys) > 0
        else None;
    if unknownWarning and not json {
        globalThis.console.warn(chalk.yellow(unknownWarning));
    }
    skipValidation = skipsValidation(options);
    yes = at(options, "yes");
    if not skipValidation {
        if not await validateBeforeArchive(changeName, changeDir, home, json) {
            return JsNull;
        }
    } elif json {
        if not yes {
            raise ArchiveBlockedError(
                "archive_confirmation_required",
                "Skipping validation requires confirmation: rerun with --yes.",
                withStoreFlag(home, "openspec archive <change-name> --json --no-validate --yes"),
            );
        }
    } else {
        timestamp = new(globalThis.Date).toISOString();
        if not yes {
            proceed = await confirmOrBlock(
                chalk.yellow(
                    "⚠️  WARNING: Skipping validation may archive invalid specs. Continue? (y/N)"
                ),
                False,
                lambda -> any {
                    ArchiveBlockedError(
                        "archive_confirmation_required",
                        "Skipping validation requires confirmation, and no answer could be read from stdin.",
                        rerunCommand(home, changeName, options),
                    )
                },
            );
            if not proceed {
                log("Archive cancelled.");
                return JsNull;
            }
        } else {
            log(chalk.yellow("\n⚠️  WARNING: Skipping validation may archive invalid specs."));
        }
        log(chalk.yellow(f"[{timestamp}] Validation skipped for change: {changeName}"));
        log(chalk.yellow(f"Affected files: {changeDir}"));
    }
    progress = await getTaskProgressForChange(
        changesDir, changeName, path.resolve(changesDir, "..", "..")
    );
    if not json {
        log(f"Task status: {formatTaskStatus(progress)}");
    }
    incompleteTasks = max(progress.total - progress.completed, 0);
    if incompleteTasks > 0 {
        if json {
            if not yes {
                raise ArchiveBlockedError(
                    "archive_tasks_incomplete",
                    f"{incompleteTasks} incomplete task(s) found for change '{changeName}'.",
                    "Complete the tasks or rerun with --yes.",
                );
            }
        } elif not yes {
            proceed = await confirmOrBlock(
                f"Warning: {incompleteTasks} incomplete task(s) found. Continue?",
                False,
                lambda -> any {
                    ArchiveBlockedError(
                        "archive_tasks_incomplete",
                        f"{incompleteTasks} incomplete task(s) found for change '{clean(changeName)}', and no answer could be read from stdin.",
                        f"Complete the tasks or rerun with {rerunCommand(home, changeName, options)}",
                    )
                },
            );
            if not proceed {
                log("Archive cancelled.");
                return JsNull;
            }
        } else {
            log(
                f"Warning: {incompleteTasks} incomplete task(s) found. Continuing due to --yes flag.",
            );
        }
    }
    archiveName = changeName
        if found(changeName, "^\\d{4}-\\d{2}-\\d{2}-")
        else f"{formatLocalDate()}-{changeName}";
    archivePath = path.join(archiveDir, archiveName);
    retirementMarker = readRetireCapabilitiesMarker(changeDir);
    retirementDeclared = retirementMarker.declared;
    authorization = await fingerprintPortableContent(path.join(changeDir, METADATA_FILENAME))
        if retirementDeclared
        else None;
    await assertArchiveDestinationAvailable(archivePath, archiveName);
    await fs.mkdir(archiveDir, rec(recursive=True));
    claimPath = archiveClaimPath(archivePath);
    archiveClaim: any = None;
    async def claimDestination {
        await assertArchiveDestinationAvailable(archivePath, archiveName);
        archiveClaim = await claimArchiveDestination(archivePath, archiveName);
        await assertArchiveDestinationAvailable(archivePath, archiveName);
    }
    try {
        specsUpdated = False;
        totals: any = None;
        specWarnings: list[str] = [];
        changeArchived = False;
        if at(options, "skipSpecs") {
            if not json {
                log("Skipping spec updates (--skip-specs flag provided).");
            }
        } else {
            specUpdates = await findSpecUpdates(changeDir, mainSpecsDir);
            if len(specUpdates) > 0 {
                if not json {
                    log("\nSpecs to update:");
                    for update in specUpdates {
                        log(f"  {update.id}: {'update' if update.exists else 'create'}");
                    }
                }
                prepared: list[any] = [];
                prepareError: any = None;
                try {
                    for update in specUpdates {
                        sourceBefore = await fingerprintPath(update.source);
                        targetBefore = await fingerprintPath(update.target);
                        built = await buildUpdatedSpec(update, changeName, rec(silent=True));
                        sourceAfter = await fingerprintPath(update.source);
                        targetAfter = await fingerprintPath(update.target);
                        if sourceBefore != sourceAfter or targetBefore != targetAfter {
                            fail(
                                f"Spec inputs for '{update.id}' changed while archive was preparing the preview.",
                            );
                        }
                        prepared.append(
                            rec(
                                update=update,
                                rebuilt=built.rebuilt,
                                counts=built.counts,
                                outcome=await decideSpecOutcome(
                                    update, built, skipValidation, retirementDeclared
                                ),
                                noRequirementBlocks=built.noRequirementBlocks,
                                unaccountedContent=built.unaccountedContent,
                                sourceFingerprint=sourceAfter,
                                sourceContentFingerprint=await fingerprintPortableContent(
                                    update.source
                                ),
                                targetFingerprint=targetAfter,
                                targetMovableFingerprint=await fingerprintMovablePath(
                                    update.target
                                ),
                            ),
                        );
                        specWarnings.extend(built.warnings);
                    }
                } except Exception as e {
                    prepareError = js_error(e);
                }
                if prepareError is None and not json {
                    for warning in specWarnings {
                        log(chalk.yellow(f"⚠️  Warning: {warning}"));
                    }
                }
                shouldUpdateSpecs = True;
                if not yes {
                    if json {
                        raise ArchiveBlockedError(
                            "archive_confirmation_required",
                            f"Updating {len(specUpdates)} spec(s) requires confirmation: rerun with --yes.",
                            withStoreFlag(home, "openspec archive <change-name> --json --yes"),
                        );
                    }
                    shouldUpdateSpecs = await confirmOrBlock(
                        "Proceed with spec updates?",
                        True,
                        lambda -> any {
                            ArchiveBlockedError(
                                "archive_confirmation_required",
                                f"Updating {len(specUpdates)} spec(s) requires confirmation, and no answer could be read from stdin.",
                                rerunCommand(home, changeName, options),
                            )
                        },
                    );
                    if not shouldUpdateSpecs {
                        log("Skipping spec updates. Proceeding with archive.");
                    }
                }
                if shouldUpdateSpecs {
                    if prepareError is None {
                        try {
                            await recheckPrepared(
                                prepared,
                                changeDir,
                                changeName,
                                mainSpecsDir,
                                retirementMarker,
                                skipValidation,
                            );
                        } except Exception as e {
                            prepareError = js_error(e);
                        }
                    }
                    if prepareError is not None {
                        message = messageOf(prepareError);
                        if json {
                            raise ArchiveBlockedError(
                                "archive_spec_update_failed",
                                message,
                                "Fix the change delta specs and rerun. No files were changed.",
                            );
                        }
                        log(message);
                        log("Aborted. No files were changed.");
                        process.exitCode = 1;
                        return JsNull;
                    }
                    if not skipValidation
                        and not await rebuiltSpecsValid(prepared, home, json, retirementMarker)
                    {
                        return JsNull;
                    }
                    await claimDestination();
                    mutations = [
                        rec(update=p.update, outcome=p.outcome, rebuilt=p.rebuilt)
                        for p in prepared
                        if p.outcome == "retire"
                            or (p.outcome == "write" and sum([p.counts[k] for k in COUNT_KEYS]) > 0)
                    ];
                    hasRetirements = len([m for m in mutations if m.outcome == "retire"]) > 0;
                    await assertDistinctMutationTargets(mutations);
                    for proposed in prepared {
                        if (await fingerprintPath(proposed.update.source))
                            != proposed.sourceFingerprint
                            or (await fingerprintPath(proposed.update.target))
                                != proposed.targetFingerprint
                        {
                            fail(
                                f"Spec inputs for '{proposed.update.id}' changed before archive could apply them. No files were changed; review the new content and rerun.",
                            );
                        }
                    }
                    specSnapshots = await captureSpecSnapshots(mutations, mainSpecsDir);
                    snapshotsByTarget: dict[str, any] = {s.target: s for s in specSnapshots};
                    mutationAttempts: list[str] = [];
                    try {
                        writeTotals = rec(added=0, modified=0, removed=0, renamed=0);
                        wroteAny = False;
                        for p in prepared {
                            if p.outcome != "write" or sum([p.counts[k] for k in COUNT_KEYS]) == 0 {
                                continue;
                            }
                            async def beforeWrite {
                                if (await fingerprintSpecInputs(p.update))
                                    != f"{p.sourceFingerprint}\n{p.targetFingerprint}"
                                {
                                    fail(
                                        f"Spec inputs for '{p.update.id}' changed before archive could write them.",
                                    );
                                }
                                mutationAttempts.append(p.update.target);
                            }
                            await writeUpdatedSpec(
                                p.update,
                                p.rebuilt,
                                p.counts,
                                merge(
                                    rec(silent=json, beforeMutate=beforeWrite),
                                    rec(displayPath=p.update.target)
                                        if isStoreSelectedRoot(home)
                                        else None,
                                ),
                            );
                            wroteAny = True;
                            addCounts(writeTotals, p.counts);
                        }
                        for p in prepared {
                            if p.outcome != "retire" {
                                continue;
                            }
                            async def beforeRetire {
                                if authorization is None {
                                    fail(
                                        f"The {METADATA_FILENAME} retirement authorization is unavailable.",
                                    );
                                }
                                await assertRetirementAuthorization(changeDir, authorization);
                                if (await fingerprintSpecInputs(p.update))
                                    != f"{p.sourceFingerprint}\n{p.targetFingerprint}"
                                {
                                    fail(
                                        f"Spec inputs for '{p.update.id}' changed before archive could retire them.",
                                    );
                                }
                                mutationAttempts.append(p.update.target);
                            }
                            async def verifyDisplaced(displacedPath: str) {
                                await assertRetirementAuthorization(changeDir, authorization);
                                if (await fingerprintMovablePath(displacedPath))
                                    != p.targetMovableFingerprint
                                {
                                    fail(
                                        f"Main spec '{p.update.id}' changed while archive was securing it for retirement.",
                                    );
                                }
                            }
                            result = await retireSpec(
                                p.update,
                                mainSpecsDir,
                                merge(
                                    rec(
                                        silent=json,
                                        deferDelete=True,
                                        beforeMutate=beforeRetire,
                                        verifyDisplaced=verifyDisplaced,
                                    ),
                                    rec(displayPath=p.update.target)
                                        if isStoreSelectedRoot(home)
                                        else None,
                                ),
                            );
                            if not result.retired {
                                continue;
                            }
                            snapshot = snapshotsByTarget.get(p.update.target);
                            if snapshot is None or result["displacedPath"] is None {
                                fail(
                                    f"Could not track the displaced main spec for '{p.update.id}' during retirement.",
                                );
                            }
                            snapshot.displacedPath = result.displacedPath;
                            snapshot.displacedFingerprint = p.targetMovableFingerprint;
                            wroteAny = True;
                            addCounts(writeTotals, p.counts);
                            realRoot = await fs.realpath(home.path).catch(
                                lambda (x: any) -> any { home.path }
                            );
                            (deletedPath, recovery) = retirementRecovery(
                                home, result["resolvedPath"] ?? p.update.target, realRoot
                            );
                            specWarnings.append(
                                f"{p.update.id} - capability retired; deleted the main spec (all requirements removed, declared by retire_capabilities) at {deletedPath}. Its section(s) went with it: Purpose. {recovery}",
                            );
                            if not json {
                                log(f"   {recovery}");
                            }
                        }
                        specsUpdated = wroteAny;
                        totals = writeTotals;
                        if not json {
                            log(
                                f"Totals: + {writeTotals.added}, ~ {writeTotals.modified}, - {writeTotals.removed}, → {writeTotals.renamed}",
                            );
                            log(
                                "Specs updated successfully."
                                    if wroteAny
                                    else "Specs already in sync; no files changed.",
                            );
                        }
                        for proposed in prepared {
                            if (await fingerprintPath(proposed.update.source))
                                != proposed.sourceFingerprint
                            {
                                fail(
                                    f"The delta for '{proposed.update.id}' changed before the change could be archived.",
                                );
                            }
                        }
                        if hasRetirements {
                            await assertRetirementAuthorization(changeDir, authorization);
                        }
                        canonicalChangeDir = FileSystemUtils.canonicalizeExistingPath(changeDir);
                        async def verifyArchivedDeltas(stagedSource: any = None) {
                            if hasRetirements {
                                await assertRetirementAuthorization(
                                    archivePath, authorization, False
                                );
                                if stagedSource {
                                    await assertRetirementAuthorization(
                                        stagedSource, authorization
                                    );
                                }
                            }
                            for proposed in prepared {
                                relative = path.relative(
                                    canonicalChangeDir, proposed.update.source
                                );
                                if (
                                    await fingerprintPortableContent(
                                        path.join(archivePath, relative)
                                    )
                                )
                                    != proposed.sourceContentFingerprint
                                {
                                    fail(
                                        f"The archived delta for '{proposed.update.id}' changed during the final move.",
                                    );
                                }
                                if stagedSource
                                    and (
                                        await fingerprintPortableContent(
                                            path.join(stagedSource, relative)
                                        )
                                    )
                                        != proposed.sourceContentFingerprint
                                {
                                    fail(
                                        f"The active delta for '{proposed.update.id}' changed during the fallback copy.",
                                    );
                                }
                            }
                        }
                        await moveDirectory(
                            changeDir,
                            archivePath,
                            rec(verifyCopiedDestination=verifyArchivedDeltas),
                        );
                        changeArchived = True;
                        await verifyArchivedDeltas();
                        await finalizeRetirementBackups(specSnapshots, mainSpecsDir);
                    } except Exception as e {
                        error = js_error(e);
                        if isinstance(error, MoveDestinationRetainedError) {
                            changeArchived = True;
                            try {
                                await finalizeRetirementBackups(specSnapshots, mainSpecsDir);
                            } except Exception as cleanupError {
                                raise RetirementCleanupError(
                                    f"{error.message} {messageOf(cleanupError)}"
                                );
                            }
                            raise error;
                        }
                        if isinstance(error, RetirementCleanupError) {
                            raise error;
                        }
                        rollbackErrors: list[str] = [];
                        try {
                            await restoreSpecSnapshots(
                                [s for s in specSnapshots if s.target in mutationAttempts],
                                mainSpecsDir,
                            );
                        } except Exception as rollbackError {
                            rollbackErrors.append(messageOf(rollbackError));
                        }
                        if changeArchived {
                            try {
                                await moveDirectory(archivePath, changeDir);
                                changeArchived = False;
                            } except Exception as rollbackError {
                                rollbackErrors.append(messageOf(rollbackError));
                            }
                        }
                        if rollbackErrors {
                            fail(
                                f"{messageOf(error)} Rollback also failed: {' '.join(rollbackErrors)}",
                            );
                        }
                        raise error;
                    }
                }
            }
        }
        if not changeArchived {
            await claimDestination();
            await fs.mkdir(archiveDir, rec(recursive=True));
            await moveDirectory(changeDir, archivePath);
            changeArchived = True;
        }
        if not json {
            log(f"Change '{changeName}' archived as '{archiveName}'.");
        }
        result = rec(
            change=changeName, archivedAs=archiveName, path=archivePath, specsUpdated=specsUpdated
        );
        if totals is not None {
            result.totals = totals;
        }
        warnings: list[any] = list(specWarnings);
        if unknownWarning {
            warnings.append(unknownWarning);
        }
        if warnings {
            result.warnings = warnings;
        }
        return result;
    } finally {
        if archiveClaim is not None {
            await promise(releaseArchiveClaim(archiveClaim, claimPath)).catch(
                lambda (x: any) -> any { None }
            );
        }
    }
}

async def:priv selectChange(changesDir: str, home: any, options: any) -> any {
    prompts = merge(await load("@inquirer/prompts"));
    changeDirs = await listActiveChangeNames(changesDir);
    if len(changeDirs) == 0 {
        globalThis.console.log("No active changes found.");
        return JsNull;
    }
    def nameRequired(why: str) -> any {
        return ArchiveBlockedError(
            "archive_change_name_required",
            f"A change name is required: {why}",
            withStoreFlag(home, f"openspec archive <change-name> {rerunFlags(options)}"),
        );
    }
    if not truthy(process.stdin["isTTY"]) or not truthy(process.stdout["isTTY"]) {
        raise nameRequired("no terminal is available to choose one from a list.");
    }
    choices: any = [rec(name=n, value=n) for n in changeDirs];
    try {
        progressList: list[any] = [];
        for id in changeDirs {
            progress = await getTaskProgressForChange(
                changesDir, id, path.resolve(changesDir, "..", "..")
            );
            progressList.append(rec(id=id, status=formatTaskStatus(progress)));
        }
        nameWidth = max([len(p.id) for p in progressList]);
        choices = [
            rec(name=f"{p.id.padEnd(nameWidth)}     {p.status}", value=p.id)
            for p in progressList
        ];
    } except Exception {
        choices = [rec(name=n, value=n) for n in changeDirs];
    }
    try {
        return await prompts.select(rec(message="Select a change to archive", choices=choices));
    } except Exception as e {
        if isNonInteractivePromptError(js_error(e)) {
            raise nameRequired("no answer could be read from stdin.");
        }
        return JsNull;
    }
}

obj ArchiveCommand(globalThis.Object) {
    async def execute(changeName: any = None, options: any = None, *rest: any) {
        json = truthy(at(options, "json"));
        try {
            home = await resolveOpenSpecRoot(
                merge(
                    rec(store=options.store) if at(options, "store") is not None else None,
                    rec(storePath=options.storePath)
                        if at(options, "storePath") is not None
                        else None,
                ),
            );
        } except Exception as e {
            if json and isRootSelectionError(js_error(e)) {
                printJsonFailure(None, toArchiveDiagnostic(e));
                return;
            }
            raise js_error(e);
        }
        if json {
            try {
                result = await runArchive(changeName, options, home, True);
                if missing(result) {
                    return;
                }
                globalThis.console.log(
                    globalThis.JSON.stringify(
                        rec(archive=result, root=toRootOutput(home)), JsNull, 2
                    ),
                );
            } except Exception as e {
                printJsonFailure(home, toArchiveDiagnostic(e));
            }
            return;
        }
        emitStoreRootBanner(home);
        await runArchive(changeName, options, home, False);
    }
}

def:priv printJsonFailure(home: any, diagnostic: any) {
    globalThis.console.log(
        globalThis.JSON.stringify(
            merge(
                rec(archive=JsNull),
                rec(root=toRootOutput(home)) if home is not None else None,
                rec(status=[diagnostic]),
            ),
            JsNull,
            2,
        ),
    );
    process.exitCode = 1;
}

with entry {
    new(
        globalThis.Function,
        "C",
        "const f = C.prototype.execute; C.prototype.execute = function (...a) { return f.apply(this, a).then(); };",
    )(ArchiveCommand);
}
