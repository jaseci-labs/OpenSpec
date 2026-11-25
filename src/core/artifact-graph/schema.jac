import from "node:fs" { readFileSync }

obj SchemaValidationError(globalThis.Error) {
    def init(message: str) {
        super.init(message);
        self.name = "SchemaValidationError";
    }
}

def loadSchema(filePath: str) -> any {
    return parseSchema(readFileSync(filePath, "utf-8"));
}

def parseSchema(yamlContent: str) -> any {
    result = SchemaYamlSchema.safeParse(need("yaml").parse(yamlContent));
    if not result.success {
        errors = ", ".join([f"{e.path.join('.')}: {e.message}" for e in result.error.issues]);
        raise SchemaValidationError(f"Invalid schema: {errors}");
    }
    schema = result.data;
    artifacts: list[any] = schema.artifacts;
    ids: list[str] = [a.id for a in artifacts];
    for i in range(len(ids)) {
        id = ids[i];
        if id in ids[:i] {
            raise SchemaValidationError(f"Duplicate artifact ID: {id}");
        }
    }
    for a in artifacts {
        for req in a.requires {
            if req not in ids {
                raise SchemaValidationError(
                    f"Invalid dependency reference in artifact '{a.id}': '{req}' does not exist"
                );
            }
        }
    }
    for req in at(schema, "apply", "requires") ?? [] {
        if req not in ids {
            raise SchemaValidationError(
                f"Invalid apply.requires reference: '{req}' does not exist (artifacts: {', '.join(ids)})",
            );
        }
    }
    cycle = findCycle(artifacts);
    if cycle {
        raise SchemaValidationError(f"Cyclic dependency detected: {cycle}");
    }
    return schema;
}

def findApplyTracksWarning(schema: any) -> any {
    tracks = at(schema, "apply", "tracks");
    generates: list[str] = [a.generates for a in schema.artifacts];
    if missing(tracks) or tracks in generates {
        return None;
    }
    return f"apply.tracks '{tracks}' does not exactly match any artifact's generates value (generates: {', '.join(generates)}), so OpenSpec cannot tell which artifact's progress it tracks. Apply still reads that file as written, but list and status count tasks.md instead. Make apply.tracks exactly equal one of those generates values, or confirm that file is maintained outside the artifact graph.";
}

def:priv findCycle(artifacts: list[any]) -> any {
    requires: dict[str, list[str]] = {a.id: a.requires for a in artifacts};
    visited: set[str] = set();
    inStack: set[str] = set();
    parent: dict[str, str] = {};
    def dfs(id: str) -> any {
        visited.add(id);
        inStack.add(id);
        for dep in requires[id] {
            if dep not in visited {
                parent[dep] = id;
                cycle = dfs(dep);
                if cycle {
                    return cycle;
                }
            } elif dep in inStack {
                path = [dep];
                current = id;
                while current != dep {
                    path.insert(0, current);
                    current = parent[current];
                }
                return " → ".join([dep, *path]);
            }
        }
        inStack.discard(id);
        return None;
    }
    for a in artifacts {
        if a.id not in visited {
            cycle = dfs(a.id);
            if cycle {
                return cycle;
            }
        }
    }
    return None;
}
