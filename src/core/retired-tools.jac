import from "node:path" { default as path }

type RetiredToolCleanup = any;
type RetiredToolIo = any;

async def cleanUpRetiredTools(projectPath: str, io: any) -> list[any] {
    results: list[any] = [];
    for tool in RETIRED_TOOLS {
        if not io.view.exists(path.join(projectPath, tool.folder))
            or not await reachesWithoutLink(projectPath, tool.folder)
        {
            continue;
        }
        commands = await reconcileCommandFiles(
            projectPath, tool.id, ALL_WORKFLOWS, rec(view=io.view, remove=io.remove)
        );
        removed: list[str] = list(commands.removed);
        kept: list[str] = list(commands.kept);
        kept.extend(commands.unchecked);
        for skillName in OPENSPEC_SKILL_NAMES {
            rel = f"{tool.folder}/skills/{skillName}";
            skillDir = path.join(projectPath, *rel.split("/"));
            if not io.view.exists(skillDir) {
                continue;
            }
            if not await reachesWithoutLink(projectPath, rel) {
                kept.append(rel);
                continue;
            }
            spot = classifySkillFile(skillDir, [], io.view);
            if spot == "released" {
                await globalThis.Promise.resolve(io.remove(path.join(skillDir, "SKILL.md")));
                removed.append(f"{rel}/SKILL.md");
            } elif spot != "missing" {
                kept.append(f"{rel}/SKILL.md");
            }
        }
        if not removed and not kept {
            continue;
        }
        if io.prune {
            await pruneEmptyParents(projectPath, ["/".join(r.split(path.sep)) for r in removed]);
        }
        results.append(rec(tool=tool, removed=removed, kept=kept));
    }
    return results;
}

def formatRetiredToolCleanup(result: any, successorSetUp: bool = False) -> list[str] {
    (tool, removed, kept) = (result.tool, result.removed, result.kept);
    advice = ""
        if successorSetUp
        else f" Set up {tool.successorName} instead: openspec init --tools {tool.successor}";
    lines = [f"{tool.name} is no longer supported: {tool.reason}.{advice}"];
    if removed {
        lines.append(
            f"  Removed {len(removed)} OpenSpec {'file' if len(removed) == 1 else 'files'} from {tool.folder}/.",
        );
    }
    if kept {
        one = len(kept) == 1;
        lines.append(
            f"  Kept {len(kept)} {'file' if one else 'files'} in {tool.folder}/ that {'differs' if one else 'differ'} from what OpenSpec generated (likely edited); delete {'it' if one else 'them'} when you're done:",
        );
        lines.extend([f"    {r}" for r in kept]);
    }
    return lines;
}
