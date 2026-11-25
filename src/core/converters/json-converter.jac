import from "node:fs" { readFileSync }
import from "node:path" { default as path }

def:priv withSource(doc: any, filePath: str) -> str {
    return globalThis.JSON.stringify(
        merge(doc, rec(metadata=merge(doc.metadata, rec(sourcePath=filePath)))), None, 2
    );
}

obj JsonConverter(globalThis.Object) {
    def init {
        super.init();
    }

    def convertSpecToJson(filePath: str) -> str {
        return withSource(
            MarkdownParser(readFileSync(filePath, "utf-8")).parseSpec(
                self.extractNameFromPath(filePath)
            ),
            filePath,
        );
    }

    async def convertChangeToJson(filePath: str) -> str {
        parser = ChangeParser(readFileSync(filePath, "utf-8"), path.dirname(filePath));
        return withSource(
            await parser.parseChangeWithDeltas(self.extractNameFromPath(filePath)), filePath
        );
    }

    def extractNameFromPath(filePath: str) -> str {
        parts = FileSystemUtils.toPosixPath(filePath).split("/");
        for i in range(len(parts) - 2, -1, -1) {
            if parts[i] in ["specs", "changes"] {
                return parts[i + 1];
            }
        }
        fileName = parts[-1];
        dot = fileName.rfind(".");
        return fileName[:dot] if dot > 0 else fileName;
    }
}

with entry {
    jsAsync(JsonConverter, ["convertChangeToJson"]);
}
