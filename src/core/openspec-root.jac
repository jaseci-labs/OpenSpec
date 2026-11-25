import from "node:fs/promises" { * as fs }
import from "node:path" { default as path }

type CreatedPathLedgerEntry = any;
type OpenSpecRootInspection = any;

glob OPENSPEC_ROOT_DIR: str = "openspec",
     OPENSPEC_CONFIG_YAML: str = "openspec/config.yaml",
     OPENSPEC_CONFIG_YML: str = "openspec/config.yml",
     OPENSPEC_SPECS_DIR: str = "openspec/specs",
     OPENSPEC_CHANGES_DIR: str = "openspec/changes",
     OPENSPEC_ARCHIVE_DIR: str = "openspec/changes/archive",
     DEFAULT_OPENSPEC_SCHEMA: str = "spec-driven",
     DIRECTORY_ANCHOR_FILE_NAME: str = ".gitkeep",
     ANCHORED_OPENSPEC_DIRS: any = [OPENSPEC_SPECS_DIR, OPENSPEC_ARCHIVE_DIR];

async def:priv pathKind(targetPath: str) -> str {
    try {
        stat = await fs.stat(targetPath);
        return "directory" if stat.isDirectory() else "file" if stat.isFile() else "other";
    } except Exception as e {
        if at(js_error(e), "code") == "ENOENT" {
            return "missing";
        }
        raise js_error(e);
    }
}

def:priv record(ledger: any, relativePath: str, absolutePath: str, isDir: bool) {
    posix = FileSystemUtils.toPosixPath(relativePath);
    ledger.push(
        rec(
            relativePath=f"{posix}/" if isDir else posix,
            absolutePath=absolutePath,
            kind="directory" if isDir else "file",
        ),
    );
}

async def inspectOpenSpecRoot(storeRoot: str) -> any {
    inspection = rec(
        present=JsNull,
        config=rec(present=JsNull),
        specs=rec(present=JsNull),
        changes=rec(present=JsNull),
        archive=rec(present=JsNull),
        healthy=False,
        diagnostics=[],
    );
    def flag(code: str, message: str, target: str) -> any {
        inspection.diagnostics.push(
            makeStoreDiagnostic("error", code, message, rec(target=target))
        );
        return inspection;
    }
    rootKind = await pathKind(storeRoot);
    if rootKind == "missing" {
        return flag("openspec_store_root_missing", "Store root does not exist.", "store.root");
    }
    if rootKind != "directory" {
        return flag(
            "openspec_store_root_not_directory", "Store root is not a directory.", "store.root"
        );
    }
    openspecKind = await pathKind(path.join(storeRoot, OPENSPEC_ROOT_DIR));
    inspection.present = openspecKind == "directory";
    if openspecKind == "missing" {
        return flag("openspec_root_missing", "Missing openspec/ directory.", "openspec.root");
    }
    if openspecKind != "directory" {
        return flag(
            "openspec_root_not_directory",
            "openspec/ exists but is not a directory.",
            "openspec.root",
        );
    }
    yamlKind = await pathKind(path.join(storeRoot, OPENSPEC_CONFIG_YAML));
    ymlKind = await pathKind(path.join(storeRoot, OPENSPEC_CONFIG_YML));
    if yamlKind == "file" or ymlKind == "file" {
        inspection.config = rec(
            present=True, path=OPENSPEC_CONFIG_YAML if yamlKind == "file" else OPENSPEC_CONFIG_YML
        );
    } else {
        inspection.config = rec(present=False);
        if yamlKind != "missing" or ymlKind != "missing" {
            flag(
                "openspec_config_not_file",
                "OpenSpec config path exists but is not a file.",
                "openspec.config",
            );
        } else {
            flag(
                "openspec_config_missing",
                "Missing openspec/config.yaml or openspec/config.yml.",
                "openspec.config",
            );
        }
    }
    seen = "directory";
    for (key, relativePath) in [
        ("specs", OPENSPEC_SPECS_DIR),
        ("changes", OPENSPEC_CHANGES_DIR),
        ("archive", OPENSPEC_ARCHIVE_DIR),
    ] {
        if key == "archive" and seen != "directory" {
            inspection.archive = rec(present=False);
            break;
        }
        seen = await pathKind(path.join(storeRoot, relativePath));
        inspection[key] = rec(present=seen == "directory");
        if seen not in ["directory", "missing"] {
            flag(
                f"openspec_{key}_not_directory",
                f"{relativePath}/ exists but is not a directory.",
                f"openspec.{key}",
            );
        }
    }
    inspection.healthy = inspection.config.present is True and len(inspection.diagnostics) == 0;
    return inspection;
}

async def:priv ensureDirectory(storeRoot: str, relativePath: str, ledger: any) {
    absolutePath = path.join(storeRoot, relativePath);
    pathIs = await pathKind(absolutePath);
    if pathIs == "directory" {
        return;
    }
    if pathIs != "missing" {
        raise new(globalThis.Error, f"{relativePath}/ exists but is not a directory.");
    }
    await fs.mkdir(absolutePath, rec(recursive=True));
    record(ledger, relativePath, absolutePath, True);
}

async def ensureDirectoryAnchor(storeRoot: str, relativeDir: str, ledger: any = None) {
    directory = path.join(storeRoot, relativeDir);
    if len(await fs.readdir(directory)) > 0 {
        return;
    }
    absolutePath = path.join(directory, DIRECTORY_ANCHOR_FILE_NAME);
    try {
        await fs.writeFile(absolutePath, "", rec(encoding="utf-8", flag="wx"));
    } except Exception as e {
        if at(js_error(e), "code") == "EEXIST" {
            return;
        }
        raise js_error(e);
    }
    record(ledger ?? [], f"{relativeDir}/{DIRECTORY_ANCHOR_FILE_NAME}", absolutePath, False);
}

async def ensureOpenSpecRoot(storeRoot: str, options: any = None) -> any {
    ledger: any = [];
    rootKind = await pathKind(storeRoot);
    if rootKind == "missing" {
        await fs.mkdir(storeRoot, rec(recursive=True));
    } elif rootKind != "directory" {
        raise new(globalThis.Error, "Store root is not a directory.");
    }
    for relativePath in [
        OPENSPEC_ROOT_DIR,
        OPENSPEC_SPECS_DIR,
        OPENSPEC_CHANGES_DIR,
        OPENSPEC_ARCHIVE_DIR,
    ] {
        await ensureDirectory(storeRoot, relativePath, ledger);
    }
    configPath = path.join(storeRoot, OPENSPEC_CONFIG_YAML);
    yamlKind = await pathKind(configPath);
    ymlKind = await pathKind(path.join(storeRoot, OPENSPEC_CONFIG_YML));
    if yamlKind != "file" and ymlKind != "file" {
        if yamlKind != "missing" or ymlKind != "missing" {
            raise new(globalThis.Error, "OpenSpec config path exists but is not a file.");
        }
        await FileSystemUtils.writeFile(
            configPath, serializeConfig(rec(schema=DEFAULT_OPENSPEC_SCHEMA))
        );
        record(ledger, OPENSPEC_CONFIG_YAML, configPath, False);
    }
    if at(options, "anchorEmptyDirectories") {
        for relativeDir in ANCHORED_OPENSPEC_DIRS {
            await ensureDirectoryAnchor(storeRoot, relativeDir, ledger);
        }
    }
    return rec(
        inspection=await inspectOpenSpecRoot(storeRoot),
        createdArtifacts=[item.relativePath for item in ledger],
        createdPaths=ledger,
    );
}

async def rollbackCreatedPaths(entries: any) {
    for item in reversed(entries) {
        done = fs.rm(item.absolutePath, rec(force=True))
            if item.kind == "file"
            else fs.rmdir(item.absolutePath);
        await done.catch(lambda (e: any) -> any { None });
    }
}
