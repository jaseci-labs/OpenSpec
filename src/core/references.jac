import from "node:fs" { promises as fs }
import from "node:os" { homedir }
import from "node:path" { default as path }
import from "node:process" { default as process }

type ReferenceIndexEntry = any;

glob:priv WHITESPACE: any = rx("\\s"),
          ENVELOPE_TAGS: list[str] = [
              "artifact",
              "dependencies",
              "dependency",
              "description",
              "instruction",
              "output",
              "path",
              "project_context",
              "rules",
              "success_criteria",
              "task",
              "template",
              "unlocks",
              "warning",
          ],
          ENVELOPE_TAG: str = f"<(/?)({'|'.join(ENVELOPE_TAGS)})(\\s[^<>]*)?>";

def:priv warning(code: str, message: str, fix: str) -> any {
    return makeStoreDiagnostic("warning", code, message, rec(target="references", fix=fix));
}

def:priv registerFix(id: str, remote: any) -> str {
    if truthy(remote) and found(remote, "^[A-Za-z0-9@:/._~+-]+$") and not remote.startsWith("-") {
        checkout = path.join(homedir(), "openspec", id);
        quoted = f'"{checkout}"' if process.platform == "win32" else f"'{checkout}'";
        return f"git clone -- {remote} {quoted} && openspec store register {quoted} --id {id}";
    }
    return f"Get a checkout from a teammate and run: openspec store register <path> --id {id}";
}

def:priv spaceAt(text: any, index: int) -> bool {
    return WHITESPACE.test(text.charAt(index));
}

def:priv stripClosingSequence(title: any) -> str {
    end: int = title.length;
    while end > 0 and spaceAt(title, end - 1) {
        end -= 1;
    }
    hashEnd = end;
    while end > 0 and title.charAt(end - 1) == "#" {
        end -= 1;
    }
    if end == hashEnd or end == 0 or not spaceAt(title, end - 1) {
        return title.trim();
    }
    return title.slice(0, end).trim();
}

def:priv parseHeadingTitle(line: any) -> any {
    size: int = line.length;
    level = 0;
    while level < 6 and level < size and line.charAt(level) == "#" {
        level += 1;
    }
    if level == 0 or level >= size or not spaceAt(line, level) {
        return JsNull;
    }
    start = level;
    while start < size and spaceAt(line, start) {
        start += 1;
    }
    return stripClosingSequence(line.slice(start));
}

def extractFirstPurposeLine(markdown: str) -> str {
    inPurpose = False;
    fenceMarker: any = JsNull;
    for line in globalThis.String.prototype.split.call(markdown, rx("\\r?\\n")) {
        fence = matchOf(line, "^\\s*(```|~~~)");
        if fence {
            if fenceMarker is JsNull {
                fenceMarker = fence[1];
            } elif fence[1] == fenceMarker {
                fenceMarker = JsNull;
            }
            continue;
        }
        if fenceMarker is not JsNull {
            continue;
        }
        title = parseHeadingTitle(line);
        if title is not JsNull {
            if inPurpose {
                return "";
            }
            inPurpose = title.toLowerCase() == "purpose";
            continue;
        }
        text: any = line.trim();
        if inPurpose and text.length > 0 {
            return text;
        }
    }
    return "";
}

async def:priv specEntry(referencedRoot: str, specId: str) -> any {
    summary = "";
    try {
        summary = sanitizeInline(
            extractFirstPurposeLine(
                await fs.readFile(
                    path.join(referencedRoot, "openspec", "specs", specId, "spec.md"), "utf-8"
                ),
            ),
        );
    } except Exception {}
    return rec(id=specId, summary=summary);
}

def fetchRecipe(storeId: str) -> str {
    return f"openspec show <spec-id> --type spec --store {storeId}";
}

def:priv specLine(spec: any) -> str {
    id = sanitizeInline(spec.id, 100);
    return f"  - {id}: {spec.summary}" if spec.summary else f"  - {id}";
}

def renderReferencedStoresBlock(entries: any) -> str {
    lines = [
        "<referenced_stores>",
        "<!-- Read-only upstream context. Fetch what you need; cite what you use. -->",
    ];
    for item in entries {
        lines.extend(renderEntryLines(item));
    }
    lines.append("</referenced_stores>");
    return "\n".join(lines);
}

def renderReferencedStoresSection(entries: any) -> str {
    lines = [
        "### Referenced Stores",
        "",
        "Read-only upstream context. Fetch what you need; cite what you use.",
        "",
    ];
    for item in entries {
        lines.extend(renderEntryLines(item));
    }
    return "\n".join(lines);
}

def sanitizeInline(value: str, maxLength: int = 300) -> str {
    replaced: any = sub(
        value,
        "[\\u0000-\\u001f\\u007f-\\u009f\\u061c\\u200e\\u200f\\u2028-\\u202e\\u2066-\\u206f]+",
        " ",
    );
    flattened: any = replaced.trim();
    return f"{flattened.slice(0, maxLength)}…" if flattened.length > maxLength else flattened;
}

def escapeEnvelopeTags(value: str) -> str {
    return sub(
        value,
        ENVELOPE_TAG,
        lambda (m: any, slash: any, tag: any, attrs: any) -> str {
            f"&lt;{slash}{tag}{'' if missing(attrs) else attrs}&gt;"
        },
        "gi",
    );
}

def escapeEnvelopeAttribute(value: str) -> str {
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace(
        '"', "&quot;"
    );
}

def:priv renderEntryLines(item: any) -> list[str] {
    lines: list[str] = [];
    resolved = item["root"] is not None;
    if resolved {
        lines.append(f"Store {item.store_id} ({item.root}):");
        lines.extend([specLine(s) for s in item["specs"] ?? []]);
        if item["fetch"] {
            lines.append(f"  Fetch: {item.fetch}");
        }
    }
    for d in item.status {
        lines.append(f"  Note: {d.message}" if resolved else f"Store {item.store_id}: {d.message}");
        if d["fix"] {
            lines.append(f"  Fix: {d.fix}");
        }
    }
    return lines;
}

def:priv renderedByteSize(entries: any) -> int {
    return globalThis.Buffer.byteLength(renderReferencedStoresBlock(entries), "utf-8");
}

def:priv unusable(id: str, code: str, message: str, fix: str) -> any {
    return rec(store_id=id, status=[warning(code, message, fix)]);
}

async def assembleReferenceIndex(input: any) -> any {
    declarations = input.references;
    if len(declarations) == 0 {
        return [];
    }
    registryEntries: any = input["registryEntries"];
    if registryEntries is None {
        try {
            registry = await readStoreRegistryState(
                rec(globalDataDir=input.globalDataDir) if truthy(input["globalDataDir"]) else rec()
            );
            registryEntries = [] if missing(registry) else listStoreRegistryEntries(registry);
        } except Exception {
            registryEntries = JsNull;
        }
    }
    includeSpecs = not same(input["includeSpecs"], False);
    resolvedRootPath = FileSystemUtils.canonicalizeExistingPath(input.resolvedRoot.path);
    entries: list[any] = [];
    for declaration in declarations {
        id = declaration.id;
        if not isValidStoreId(id) {
            entries.append(
                unusable(
                    id,
                    "reference_invalid_id",
                    f"Reference '{id}' is not a valid store id.",
                    "Use kebab-case store ids in the references list.",
                ),
            );
            continue;
        }
        if same(input.resolvedRoot["storeId"], id) {
            continue;
        }
        if registryEntries is JsNull {
            entries.append(
                unusable(
                    id,
                    "reference_registry_unreadable",
                    f"Referenced store '{id}' cannot be checked: the store registry is unreadable.",
                    "Run: openspec store doctor",
                ),
            );
            continue;
        }
        matches = [e for e in registryEntries if e.id == id];
        if not matches {
            entries.append(
                unusable(
                    id,
                    "reference_unresolved",
                    f"Referenced store '{id}' is not registered on this machine.",
                    registerFix(id, declaration["remote"]),
                ),
            );
            continue;
        }
        inspection: any = None;
        try {
            inspection = await inspectRegisteredStore(
                id, getStoreRootForBackend(matches[0].backend)
            );
        } except Exception {
            inspection = rec(kind="inspection_error");
        }
        if inspection.kind != "ok" {
            entries.append(
                unusable(
                    id,
                    "reference_root_unhealthy",
                    f"Referenced store '{id}' is registered but not usable ({inspection.kind.replace('_', ' ')}).",
                    f"Run: openspec store doctor {id}",
                ),
            );
            continue;
        }
        storeRoot = inspection.canonicalRoot;
        if storeRoot == resolvedRootPath {
            continue;
        }
        if not includeSpecs {
            entries.append(rec(store_id=id, root=storeRoot, status=[]));
            continue;
        }
        specs: any = await globalThis.Promise.all([
            promise(specEntry(storeRoot, specId))
            for specId in await getSpecIds(storeRoot)
        ]);
        item = rec(store_id=id, root=storeRoot, specs=specs, fetch=fetchRecipe(id), status=[]);
        entries.append(item);
        if renderedByteSize(entries) > MAX_CONTEXT_SIZE {
            low = 0;
            high = len(specs);
            while low < high {
                mid = (low + high + 1) // 2;
                item.specs = specs.slice(0, mid);
                if renderedByteSize(entries) > MAX_CONTEXT_SIZE {
                    high = mid - 1;
                } else {
                    low = mid;
                }
            }
            item.specs = specs.slice(0, low);
            item.status.push(
                warning(
                    "reference_index_truncated",
                    f"Referenced store '{id}' index truncated at the 50KB budget ({low} of {len(specs)} specs listed).",
                    f"List the rest directly: openspec list --specs --store {id}",
                ),
            );
        }
    }
    return entries;
}
