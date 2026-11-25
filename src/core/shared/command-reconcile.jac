import from "node:path" { default as path }
import from "node:fs" { promises as fsp }

type CommandReconcileResult = any;
type CommandReconcileIo = any;

def classifyCommandFiles(
    projectPath: str,
    toolId: str,
    workflows: any,
    view: any = None,
    includeFormerRoots: bool = False,
) -> any {
    view = view ?? DISK_VIEW;
    result = rec(generated=[], kept=[], unchecked=[]);
    adapter = CommandAdapterRegistry.get(toolId);
    if not adapter {
        return result;
    }
    currentRoot = at(AI_TOOLS.find(lambda (t: any) -> bool { t.value == toolId }), "skillsDir");
    formerRoots = (LEGACY_TOOL_ROOTS[toolId] ?? []) if includeFormerRoots else [];
    present: list[any] = [];
    for workflow in ALL_WORKFLOWS {
        current = adapter.getFilePath(workflow);
        paths: list[any] = [current];
        for former in formerRoots {
            formerPath = legacyCommandPath(current, currentRoot, former.root)
                if currentRoot
                else None;
            if formerPath {
                paths.append(formerPath);
            }
        }
        for cmdPath in paths {
            try {
                fullPath = FileSystemUtils.resolveProjectArtifactPath(projectPath, cmdPath);
            } except Exception {
                lexical = path.join(projectPath, cmdPath);
                if view.exists(lexical) or linkOf(view, lexical) is not None {
                    result.unchecked.append(cmdPath);
                }
                continue;
            }
            if view.exists(fullPath) {
                present.append((workflow, cmdPath, fullPath));
            }
        }
    }
    if not present {
        return result;
    }
    generatedByPath: dict[str, list[str]] = {};
    for workflowSet in [
        globalThis.Array.from(new(globalThis.Set, [p[0] for p in present])),
        workflows,
        ALL_WORKFLOWS,
    ] {
        try {
            commands = generateCommands(getCommandContents(workflowSet), adapter);
        } except Exception {
            continue;
        }
        for cmd in commands {
            generatedByPath.setdefault(cmd.path, []).append(
                normalizeCommandContent(cmd.fileContent)
            );
        }
    }
    for (workflow, cmdPath, fullPath) in present {
        try {
            content = view.read(fullPath);
            if normalizeCommandContent(content)
                in generatedByPath.get(adapter.getFilePath(workflow), [])
                or isReleasedGeneratedContent(content)
            {
                result.generated.append(rec(cmdPath=cmdPath, fullPath=fullPath));
            } else {
                result.kept.append(cmdPath);
            }
        } except Exception {
            result.unchecked.append(cmdPath);
        }
    }
    return result;
}

glob:priv DISK_IO: any = rec(
    view=DISK_VIEW, remove=lambda (fullPath: str) -> any { fsp.unlink(fullPath) }
);

async def reconcileCommandFiles(
    projectPath: str, toolId: str, workflows: any, io: any = None
) -> any {
    io = io ?? DISK_IO;
    found = classifyCommandFiles(projectPath, toolId, workflows, io.view);
    removed: list[str] = [];
    for item in found.generated {
        try {
            await globalThis.Promise.resolve(io.remove(item.fullPath));
            removed.append(item.cmdPath);
        } except Exception {
            found.unchecked.append(item.cmdPath);
        }
    }
    return rec(removed=removed, kept=found.kept, unchecked=found.unchecked);
}

def:priv block(paths: any, headline: str, advice: str) -> list[str] {
    lines = [headline];
    lines.extend([f"  {p}" for p in paths]);
    lines.append(advice);
    return lines;
}

def formatKeptCommandFiles(result: any) -> list[list[str]] {
    def files(n: int) -> str {
        return f"command {'file' if n == 1 else 'files'}";
    }
    blocks: list[list[str]] = [];
    (kept, unchecked) = (result.kept, result.unchecked);
    if len(kept) > 0 {
        blocks.append(
            block(
                kept,
                f"Kept {len(kept)} {files(len(kept))} that {'does' if len(kept) == 1 else 'do'} not match what OpenSpec generated (likely edited):",
                "Move anything worth keeping into the skill, then delete by hand.",
            ),
        );
    }
    if len(unchecked) > 0 {
        blocks.append(
            block(
                unchecked,
                f"Left {len(unchecked)} {files(len(unchecked))} in place because {'it' if len(unchecked) == 1 else 'they'} could not be read or removed:",
                "Check the file permissions or symbolic links, then delete by hand.",
            ),
        );
    }
    return blocks;
}
