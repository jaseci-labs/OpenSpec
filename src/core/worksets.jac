import from "node:fs" { promises as fs }
import from "node:path" { isAbsolute }

type WorksetPathOptions = any;
type WorksetMember = any;
type Workset = any;
type WorksetsState = any;

glob WORKSETS_DIR_NAME: str = "worksets",
     WORKSETS_FILE_NAME: str = "worksets.yaml";

glob:priv z: any = need("zod").z,
          WorksetsStateSchema: any = z.object(
              rec(
                  version=z.literal(1),
                  worksets=z.record(
                      z.string(),
                      z.object(
                          rec(
                              tool=z.string().min(1).optional(),
                              members=z.array(
                                  z.object(rec(name=z.string(), path=z.string())).strict()
                              ),
                          ),
                      ).strict(),
                  ),
              ),
          ).strict(),
          worksetsLockError: any = makeLockErrorFactory(
              rec(
                  createSubject="the worksets lock file",
                  busyMessage="The worksets file is busy.",
                  code="workset_file_busy",
                  target="workset.file",
              ),
          );

def:priv byName(names: any) -> any {
    return globalThis.Array.prototype.sort.call(
        names, lambda (a: any, b: any) -> int { a.localeCompare(b) }
    );
}

def:priv has_(state: any, name: str) -> bool {
    return globalThis.Object.prototype.hasOwnProperty.call(state.worksets, name);
}

def getWorksetsDir(options: any = None) -> str {
    return FileSystemUtils.joinPath(
        at(options, "globalDataDir") ?? getGlobalDataDir(), WORKSETS_DIR_NAME
    );
}

def getWorksetsFilePath(options: any = None) -> str {
    return FileSystemUtils.joinPath(getWorksetsDir(options), WORKSETS_FILE_NAME);
}

def getWorksetCodeWorkspacePath(name: str, options: any = None) -> str {
    return FileSystemUtils.joinPath(getWorksetsDir(options), f"{name}.code-workspace");
}

def validateWorksetName(name: str) -> str {
    if not isKebabId(name) {
        raise StoreError(
            f"Workset name '{name}' {KEBAB_ID_DESCRIPTION}.",
            "invalid_workset_name",
            rec(target="workset.name", fix=KEBAB_ID_FIX),
        );
    }
    return name;
}

def memberListProblem(members: any) -> any {
    if not len(members) {
        return "members must not be empty";
    }
    seen: set[str] = set();
    for member in members {
        labelProblem = memberLabelProblem(member.name);
        if labelProblem is not JsNull {
            return labelProblem;
        }
        if member.name in seen {
            return f"duplicate member name '{member.name}' (use the name=path form to label members distinctly)";
        }
        seen.add(member.name);
        if not isAbsolute(member.path) {
            return f"member path '{member.path}' must be absolute";
        }
    }
    return JsNull;
}

def memberLabelProblem(label: str) -> any {
    return folderStyleNameProblem(label, "member name");
}

def:priv invalidWorksetsFileError(message: str, options: any) -> any {
    return StoreError(
        f"Invalid worksets file: {message}",
        "invalid_workset_file",
        rec(target="workset.file", fix=f"Repair or remove {getWorksetsFilePath(options)}."),
    );
}

def:priv validated(state: any, options: any) -> any {
    result = WorksetsStateSchema.safeParse(state);
    if not result.success {
        raise invalidWorksetsFileError(formatZodIssues(result.error), options);
    }
    return result.data;
}

def parseWorksetsState(content: str, options: any = None) -> any {
    raw: any = None;
    try {
        raw = need("yaml").parse(content);
    } except Exception as e {
        err = js_error(e);
        raise invalidWorksetsFileError(
            err.message
                if globalThis.Error.prototype.isPrototypeOf(err)
                else globalThis.String(err),
            options,
        );
    }
    data = validated(raw, options);
    for (name, item) in globalThis.Object.entries(data.worksets) {
        if not isKebabId(name) {
            raise invalidWorksetsFileError(
                f"workset name '{name}' {KEBAB_ID_DESCRIPTION}", options
            );
        }
        problem = memberListProblem(item.members);
        if problem is not JsNull {
            raise invalidWorksetsFileError(f"workset '{name}': {problem}", options);
        }
    }
    return data;
}

def serializeWorksetsState(state: any, options: any = None) -> str {
    worksets = validated(state, options).worksets;
    return need("yaml").stringify(
        rec(
            version=1,
            worksets=globalThis.Object.fromEntries([
                [name, worksets[name]]
                for name in byName(globalThis.Object.keys(worksets))
            ]),
        ),
    );
}

async def readWorksetsState(options: any = None) -> any {
    filePath = getWorksetsFilePath(options);
    if not await pathIsFile(filePath) {
        return rec(version=1, worksets=rec());
    }
    return parseWorksetsState(await fs.readFile(filePath, "utf-8"), options);
}

async def:priv save(next: any, options: any) {
    await writeFileAtomically(getWorksetsFilePath(options), serializeWorksetsState(next, options));
}

async def updateWorksetsState(updater: any, options: any = None) -> any {
    async def apply(state: any) -> any {
        next = await globalThis.Promise.resolve(updater(state));
        await save(next, options);
        return next;
    }
    return await withWorksetsLock(apply, options);
}

async def withWorksetsLock(fn: any, options: any = None) -> any {
    lockPath = f"{getWorksetsFilePath(options)}.lock";
    lock = await acquireFileLock(rec(lockPath=lockPath, errorFor=worksetsLockError));
    try {
        return await globalThis.Promise.resolve(fn(await readWorksetsState(options)));
    } finally {
        await releaseFileLock(lock, lockPath);
    }
}

def worksetNotFoundError(name: str, state: any) -> any {
    savedNames = byName(globalThis.Object.keys(state.worksets));
    return StoreError(
        f"Workset '{name}' is not saved on this machine.",
        "workset_not_found",
        rec(
            target="workset.name",
            fix=f"Saved worksets: {savedNames.join(', ')}. See them with: openspec workset list"
                if len(savedNames)
                else f"Create it first: openspec workset create {name}",
        ),
    );
}

def:priv toolPart(source: any) -> any {
    return None if source["tool"] is None else rec(tool=source.tool);
}

def withWorkset(state: any, workset: any) -> any {
    if has_(state, workset.name) {
        raise StoreError(
            f"Workset '{workset.name}' already exists.",
            "workset_exists",
            rec(
                target="workset.name",
                fix=f"Choose another name, or remove it first: openspec workset remove {workset.name}",
            ),
        );
    }
    item = merge(toolPart(workset), rec(members=workset.members));
    return rec(
        version=1,
        worksets=merge(state.worksets, globalThis.Object.fromEntries([[workset.name, item]])),
    );
}

def withoutWorkset(state: any, name: str) -> any {
    if not has_(state, name) {
        raise worksetNotFoundError(name, state);
    }
    remaining = merge(state.worksets);
    globalThis.Reflect.deleteProperty(remaining, name);
    return rec(version=1, worksets=remaining);
}

async def removeWorkset(name: str, options: any = None) {
    async def apply(state: any) {
        await save(withoutWorkset(state, name), options);
        await fs.rm(getWorksetCodeWorkspacePath(name, options), rec(force=True));
    }
    await withWorksetsLock(apply, options);
}

def:priv toWorkset(name: str, item: any) -> any {
    return merge(rec(name=name), toolPart(item), rec(members=item.members));
}

def listWorksets(state: any) -> any {
    return [
        toWorkset(name, state.worksets[name])
        for name in byName(globalThis.Object.keys(state.worksets))
    ];
}

def getWorkset(state: any, name: str) -> any {
    return toWorkset(name, state.worksets[name]) if has_(state, name) else JsNull;
}

def buildWorksetCodeWorkspaceJson(members: any) -> str {
    return globalThis.JSON.stringify(
        rec(folders=[rec(name=m.name, path=m.path) for m in members]), JsNull, 2
    )
        + "\n";
}
