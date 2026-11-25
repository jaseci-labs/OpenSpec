import from "node:path" { default as path }
import from "node:fs" { promises as fs }

glob:priv VERBS: list[tuple[str, str, str]] = [
    ("added", "ADDED", "Add"),
    ("modified", "MODIFIED", "Modify"),
    ("removed", "REMOVED", "Remove"),
];

def:priv removedInOrder(plan: any) -> list[any] {
    blocks: any = list(plan.removedBlocks);
    out: list[any] = [];
    for name in plan.removed {
        index = blocks.findIndex(lambda (b: any) -> bool { b.name == name });
        header = f"### Requirement: {name}";
        out.append(
            rec(headerLine=header, name=name, raw=header)
                if index == -1
                else blocks.splice(index, 1)[0],
        );
    }
    return out;
}

obj ChangeParser(MarkdownParser) {
    def init(content: str, changeDir: str) {
        super.init(content);
        self.changeDir = changeDir;
    }

    async def parseChangeWithDeltas(name: str) -> any {
        sections = self.parseSections();
        why: any = at(self.findSection(sections, "Why"), "content") or "";
        whatChanges: any = at(self.findSection(sections, "What Changes"), "content") or "";
        if not why {
            raise new(globalThis.Error, "Change must have a Why section");
        }
        if not whatChanges {
            raise new(globalThis.Error, "Change must have a What Changes section");
        }
        deltas: list[any] = [];
        hasDeltaSections = False;
        for spec in await discoverSpecFiles(path.join(self.changeDir, "specs")) {
            try {
                plan = parseDeltaSpec(await fs.readFile(spec.specFile, "utf-8"));
                if any([truthy(v) for v in globalThis.Object.values(plan.sectionPresence)]) {
                    hasDeltaSections = True;
                }
                deltas.extend(self.parseSpecDeltas(spec.id, plan));
            } except Exception {
                continue;
            }
        }
        return rec(
            name=name,
            why=why.trim(),
            whatChanges=whatChanges.trim(),
            deltas=deltas if hasDeltaSections else self.parseDeltas(whatChanges),
            metadata=rec(version="1.0.0", format="openspec-change"),
        );
    }

    def parseRequirements(section: any) -> any {
        return super.parseRequirements(
            merge(
                section,
                rec(
                    children=[
                        c
                        for c in section.children
                        if found(c.title.trim(), "^Requirement:\\s*\\S", "i")
                    ],
                ),
            ),
        );
    }

    def parseSpecDeltas(specName: str, plan: any) -> list[any] {
        deltas: list[any] = [];
        for (key, operation, verb) in VERBS {
            for req in self.toRequirements(
                removedInOrder(plan) if key == "removed" else plan[key]
            ) {
                deltas.append(
                    rec(
                        spec=specName,
                        operation=operation,
                        description=f"{verb} requirement: {req.text}",
                        requirement=req,
                        requirements=[req],
                    ),
                );
            }
        }
        for rename in plan.renamed {
            deltas.append(
                rec(
                    spec=specName,
                    operation="RENAMED",
                    description=f'Rename requirement from "{rename["from"]}" to "{rename.to}"',
                    rename=rename,
                ),
            );
        }
        return deltas;
    }

    def toRequirements(blocks: any) -> list[any] {
        out: list[any] = [];
        for block in blocks {
            lines = block.raw.split("\n");
            title: any = sub(lines[0], "^###\\s*", "", "");
            section = MarkdownParser(
                "\n".join([f"### {title.trim()}"] + lines[1:])
            ).parseSections()[0];
            out.extend(
                self.parseRequirements(rec(level=2, title="", content="", children=[section]))
            );
        }
        return out;
    }
}

with entry {
    new(
        globalThis.Function,
        "C",
        "const f = C.prototype.parseChangeWithDeltas; C.prototype.parseChangeWithDeltas = function (...a) { return f.apply(this, a).then(); };",
    )(ChangeParser);
}
