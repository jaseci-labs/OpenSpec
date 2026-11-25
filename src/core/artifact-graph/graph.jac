obj ArtifactGraph(globalThis.Object) {
    def init(schema: any) {
        super.init();
        self.schema = schema;
        self.artifacts = {a.id: a for a in schema.artifacts};
        self.declarationOrder = {a.id: i for (i, a) in enumerate(schema.artifacts)};
    }

    def ordered(ids: list[str]) -> list[str] {
        rank: dict[str, int] = self.declarationOrder;
        return sorted(
            ids, key=lambda (id: str) -> int { rank.get(id, globalThis.Number.MAX_SAFE_INTEGER) }
        );
    }

    static def fromYaml(filePath: str) -> ArtifactGraph {
        return ArtifactGraph(loadSchema(filePath));
    }

    static def fromYamlContent(yamlContent: str) -> ArtifactGraph {
        return ArtifactGraph(parseSchema(yamlContent));
    }

    static def fromSchema(schema: any) -> ArtifactGraph {
        return ArtifactGraph(schema);
    }

    def getArtifact(id: str) -> any {
        artifacts: dict[str, any] = self.artifacts;
        return artifacts.get(id);
    }

    def getAllArtifacts -> list[any] {
        artifacts: dict[str, any] = self.artifacts;
        return list(artifacts.values());
    }

    def getName -> str {
        return self.schema.name;
    }

    def getVersion -> int {
        return self.schema.version;
    }

    def getBuildOrder -> list[str] {
        artifacts: list[any] = self.getAllArtifacts();
        degree: dict[str, int] = {a.id: len(a.requires) for a in artifacts};
        dependents: dict[str, list[str]] = {a.id: [] for a in artifacts};
        for a in artifacts {
            for req in a.requires {
                dependents[req].append(a.id);
            }
        }
        queue = self.ordered([id for id in degree if degree[id] == 0]);
        result: list[str] = [];
        while queue {
            current = queue.pop(0);
            result.append(current);
            for dep in dependents[current] {
                degree[dep] -= 1;
                if degree[dep] == 0 {
                    queue.append(dep);
                }
            }
            queue = self.ordered(queue);
        }
        return result;
    }

    def getNextArtifacts(completed: any) -> list[str] {
        return self.ordered([
            a.id
            for a in self.getAllArtifacts()
            if not completed.has(a.id) and all([completed.has(req) for req in a.requires])
        ]);
    }

    def isComplete(completed: any) -> bool {
        return all([completed.has(a.id) for a in self.getAllArtifacts()]);
    }

    def getBlocked(completed: any) -> any {
        unmet = [
            [a.id, self.ordered([req for req in a.requires if not completed.has(req)])]
            for a in self.getAllArtifacts()
            if not completed.has(a.id)
        ];
        return globalThis.Object.fromEntries([pair for pair in unmet if pair[1]]);
    }
}
