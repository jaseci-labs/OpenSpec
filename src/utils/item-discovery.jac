import from "fs" { promises as fs }
import from "path" { default as path }
import from "node:process" { default as process }

async def:priv childDirs(base: any, segments: list[str], exclude: list[str]) -> list[str] {
    try {
        entries = await fs.readdir(
            path.join(base ?? process.cwd(), "openspec", *segments), rec(withFileTypes=True)
        );
    } except Exception {
        return [];
    }
    return sorted([
        e.name
        for e in entries
        if e.isDirectory() and e.name not in exclude and not e.name.startswith(".")
    ]);
}

async def getActiveChangeIds(base: any = None) -> list[str] {
    return await childDirs(base, ["changes"], ["archive"]);
}

async def getSpecIds(base: any = None) -> list[str] {
    return [
        spec.id
        for spec in await discoverSpecFiles(path.join(base ?? process.cwd(), "openspec", "specs"))
    ];
}

async def getArchivedChangeIds(base: any = None) -> list[str] {
    return await childDirs(base, ["changes", "archive"], []);
}
