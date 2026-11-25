import from "fs" { promises as fs }
import from "path" { default as path }

type DiscoveredSpec = any;

type UnreadDeltaFile = any;

async def:priv readEntries(dir: str, tolerated: list[str]) -> any {
    try {
        return await fs.readdir(dir, rec(withFileTypes=True));
    } except Exception as e {
        if at(js_error(e), "code") in tolerated {
            return [];
        }
        raise js_error(e);
    }
}

async def:priv isLinkedFile(file: str) -> bool {
    try {
        return (await fs.stat(file)).isFile();
    } except Exception as e {
        if at(js_error(e), "code") != "ENOENT" {
            raise js_error(e);
        }
        return False;
    }
}

def:priv sortedBy(items: list[any], key: str) -> list[any] {
    return sorted(items, key=lambda (item: any) -> any { item[key] });
}

async def discoverSpecFiles(specsRoot: str) -> list[any] {
    results: list[any] = [];
    async def walk(dir: str, segments: list[str]) {
        for ent in await readEntries(dir, ["ENOENT"]) {
            name: str = ent.name;
            specFile = path.join(dir, name);
            if name.startswith(".") {
                continue;
            } elif ent.isDirectory() {
                await walk(specFile, segments + [name]);
            } elif name == "spec.md"
                and segments
                and (ent.isFile() or ent.isSymbolicLink() and await isLinkedFile(specFile))
            {
                assertDiscoveredSpecFile(specsRoot, specFile);
                results.append(rec(id="/".join(segments), specFile=specFile));
            }
        }
    }
    await walk(specsRoot, []);
    return sortedBy(results, "id");
}

async def findUnreadDeltaFiles(specsRoot: str) -> list[any] {
    results: list[any] = [];
    async def walk(dir: str, segments: list[str]) {
        for ent in await readEntries(dir, ["ENOENT", "ENOTDIR"]) {
            name: str = ent.name;
            filePath = path.join(dir, name);
            if name.startswith(".") {
                continue;
            }
            if ent.isDirectory() {
                await walk(filePath, segments + [name]);
                continue;
            }
            if not (ent.isFile() or ent.isSymbolicLink())
                or name == "spec.md"
                or not name.lower().endswith(".md")
            {
                continue;
            }
            try {
                if ent.isSymbolicLink() and not (await fs.stat(filePath)).isFile() {
                    continue;
                }
                content = await fs.readFile(filePath, "utf-8");
            } except Exception as e {
                if at(js_error(e), "code") == "ENOENT" {
                    continue;
                }
                raise js_error(e);
            }
            if not any(globalThis.Object.values(parseDeltaSpec(content).sectionPresence)) {
                continue;
            }
            capability = "/".join(segments) if segments else name[:-3];
            results.append(rec(path="/".join(segments + [name]), expected=f"{capability}/spec.md"));
        }
    }
    await walk(specsRoot, []);
    return sortedBy(results, "path");
}

async def hasAnyFileUnder(dirPath: str) -> bool {
    for ent in await readEntries(dirPath, ["ENOENT"]) {
        if not ent.name.startswith(".")
            and (
                ent.isFile()
                or ent.isSymbolicLink()
                or ent.isDirectory() and await hasAnyFileUnder(path.join(dirPath, ent.name))
            )
        {
            return True;
        }
    }
    return False;
}
