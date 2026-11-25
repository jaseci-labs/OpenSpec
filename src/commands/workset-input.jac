import from "node:path" { default as path }

def:priv toolError(message: str, fix: str, code: str = "workset_tool_unavailable") -> any {
    return StoreError(message, code, rec(target="workset.tool", fix=fix));
}

def:priv memberInvalidError(problem: str) -> any {
    return StoreError(
        f"Invalid workset member: {problem}.",
        "workset_member_invalid",
        rec(
            target="workset.member",
            fix="Pass --member <path> with an existing folder, or --member <name>=<path> to label it.",
        ),
    );
}

def:priv enabled(table: any) -> list[any] {
    return [o for o in table if isOpenerEnabled(o)];
}

async def:priv resolveMemberFlag(raw: any) -> any {
    separator: int = raw.indexOf("=");
    label: any = raw.slice(0, separator) if separator > 0 else None;
    rawPath: any = raw.slice(separator + 1) if separator > 0 else raw;
    if len(rawPath) == 0 {
        raise memberInvalidError(f"'{raw}' has no path");
    }
    resolvedPath = path.resolve(expandUserPath(rawPath));
    if not await pathIsDirectory(resolvedPath) {
        raise memberInvalidError(f"'{rawPath}' is not an existing folder");
    }
    name = label ?? path.basename(resolvedPath);
    problem = memberLabelProblem(name);
    if problem is not JsNull {
        raise memberInvalidError(problem);
    }
    return rec(name=name, path=resolvedPath);
}

async def resolveMemberFlags(flags: any) -> any {
    settled = await globalThis.Promise.allSettled([promise(resolveMemberFlag(f)) for f in flags]);
    members: list[any] = [];
    for result in settled {
        if result.status == "rejected" {
            raise result.reason;
        }
        members.append(result.value);
    }
    return members;
}

def assertKnownTool(tool: str, table: any) {
    if findOpener(table, tool) is JsNull {
        raise toolUnknownError(tool, table);
    }
}

def finalizeWorkset(name: str, members: any, tool: any, table: any) -> any {
    problem = memberListProblem(members);
    if problem is not JsNull {
        raise memberInvalidError(problem);
    }
    if tool is not None {
        assertKnownTool(tool, table);
    }
    return merge(rec(name=name), None if tool is None else rec(tool=tool), rec(members=members));
}

def formatMemberRows(members: any) -> any {
    width = max([len(m.name) for m in members], default=0);
    return [f"{m.name.padEnd(width)}  {m.path}" for m in members];
}

def toolUnknownError(toolId: str, table: any) -> any {
    return toolError(
        f"Unknown tool '{toolId}'.",
        f'Known tools: {", ".join([o.id for o in enabled(table)])}. Add new tools under "openers" in {getGlobalConfigPath()}.',
        "workset_tool_unknown",
    );
}

def firstInstalledAlternative(table: any, excludeId: any, scan: any = None) -> any {
    for candidate in table {
        if candidate.id != excludeId
            and isOpenerEnabled(candidate)
            and isOpenerCommandAvailable(candidate.command, scan)
        {
            return candidate.id ?? JsNull;
        }
    }
    return JsNull;
}

def toolUnavailableError(opener: any, table: any, worksetName: str, scan: any = None) -> any {
    alternative = firstInstalledAlternative(table, opener.id, scan);
    return toolError(
        f"{opener.label} ('{opener.command}') is not on PATH.",
        f"Install '{opener.command}', then rerun: openspec workset open {worksetName}"
            if alternative is JsNull
            else f"Install '{opener.command}' or run: openspec workset open {worksetName} --tool {alternative}",
    );
}

def noToolInstalledError(table: any, worksetName: str) -> any {
    return toolError(
        "None of the known tools is on PATH.",
        f"Install one of: {', '.join([o.command for o in enabled(table)])}. Then rerun: openspec workset open {worksetName}",
    );
}
