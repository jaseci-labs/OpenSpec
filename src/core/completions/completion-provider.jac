import from "node:process" { default as process }

glob:priv KINDS: list[str] = ["changeCache", "specCache", "schemaCache"];

async def:priv loadSchemaNames(projectRoot: any) -> any {
    import from "../artifact-graph/resolver" { listSchemas }
    return listSchemas(projectRoot);
}

obj CompletionProvider(globalThis.Object) {
    def init(cacheTTLMs: int = 2000, projectRoot: str = process.cwd()) {
        super.init();
        self.cacheTTL = cacheTTLMs;
        self.projectRoot = projectRoot;
        self.cache = {};
    }

    def fresh(kind: str, now: int) -> bool {
        return kind in self.cache and now - self.cache[kind][1] < self.cacheTTL;
    }

    async def cached(kind: str, fetch: any) -> any {
        now = globalThis.Date.now();
        if not self.fresh(kind, now) {
            self.cache[kind] = (await fetch(self.projectRoot), now);
        }
        return self.cache[kind][0];
    }

    async def getChangeIds -> any {
        return await self.cached("changeCache", getActiveChangeIds);
    }

    async def getSpecIds -> any {
        return await self.cached("specCache", getSpecIds);
    }

    async def getSchemaNames -> any {
        return await self.cached("schemaCache", loadSchemaNames);
    }

    async def getAllIds -> any {
        (changeIds, specIds) = await globalThis.Promise.all([
            self.getChangeIds(),
            self.getSpecIds(),
        ]);
        return rec(changeIds=changeIds, specIds=specIds);
    }

    def clearCache {
        self.cache = {};
    }

    def getCacheStats -> any {
        now = globalThis.Date.now();
        return rec(
            **{
                kind: rec(
                    valid=self.fresh(kind, now),
                    age=(now - self.cache[kind][1]) if kind in self.cache else None,
                )
                for kind in KINDS
            },
        );
    }
}

with entry {
    jsAsync(CompletionProvider, ["getChangeIds", "getSpecIds", "getSchemaNames", "getAllIds"]);
}
