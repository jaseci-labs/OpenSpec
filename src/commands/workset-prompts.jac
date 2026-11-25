import from "node:path" { default as path }

def:priv log(text: str) {
    globalThis.console.log(text);
}

async def:priv prompts -> any {
    return merge(await load("@inquirer/prompts"));
}

def:priv resolvedDir(value: str) -> str {
    return path.resolve(expandUserPath(value));
}

async def composeInteractively(givenName: any, input: any, table: any) -> any {
    ask = await prompts();
    log("[1/3] Name the workset");
    name: any = None;
    if givenName is not None {
        name = validateWorksetName(givenName);
        log(f"  Workset name: {name}");
    } else {
        def validName(value: str) -> any {
            try {
                validateWorksetName(value);
                return True;
            } except Exception as e {
                return asErrorMessage(js_error(e));
            }
        }
        name = await ask.input(rec(message="Workset name:", required=True, validate=validName));
    }
    tool: any = input["tool"];
    if tool is not None {
        assertKnownTool(tool, table);
    }
    log("");
    log("[2/3] Add member folders (the first one is the primary - sessions start there)");
    members: list[any] = await resolveMemberFlags(input.memberFlags);
    if members {
        finalizeWorkset(name, members, tool, table);
        for m in members {
            log(f"  Added '{m.name}' ({m.path})");
        }
    }
    def taken(label: str) -> bool {
        return label in [m.name for m in members];
    }
    async def existingFolder(value: str) -> any {
        if not await pathIsDirectory(resolvedDir(value)) {
            return f"'{value}' is not an existing folder";
        }
        return True;
    }
    def freeLabel(value: str) -> any {
        problem = memberLabelProblem(value);
        if problem is not JsNull {
            return problem;
        }
        return f"duplicate member name '{value}'" if taken(value) else True;
    }
    while True {
        if members {
            next = await ask.select(
                rec(
                    message="Add another folder or finish:",
                    choices=[
                        rec(name="Finish", value="finish"),
                        rec(name="Add another folder", value="add"),
                    ],
                    default="finish",
                ),
            );
            if next == "finish" {
                break;
            }
        }
        rawPath = await ask.input(
            merge(
                rec(message="Folder path:"),
                None if members else rec(default=".", prefill="editable"),
                rec(required=True, validate=existingFolder),
            ),
        );
        resolvedPath = resolvedDir(rawPath);
        label = path.basename(resolvedPath);
        if memberLabelProblem(label) is not JsNull or taken(label) {
            label = await ask.input(
                rec(
                    message="Name this member (the folder label):",
                    required=True,
                    validate=freeLabel,
                ),
            );
        }
        members.append(rec(name=label, path=resolvedPath));
        log(f"  Added '{label}' ({resolvedPath})");
    }
    log("");
    log("[3/3] Choose your tool");
    if tool is None {
        choices = listOpenerChoices(table);
        available = [c for c in choices if c.available];
        if not available {
            log("  None of the known tools is on PATH; not saving a preference.");
            known: any = [f"{c.opener.id} {'' if missing(c['note']) else c.note}" for c in choices];
            log(f"  (Known tools: {', '.join([k.trim() for k in known])})");
        } else {
            tool = await promptToolFromChoices(available);
        }
    }
    return finalizeWorkset(name, members, tool, table);
}

async def promptToolFromChoices(available: any) -> any {
    return await (await prompts()).select(
        rec(
            message="Open with:",
            choices=[rec(name=c.opener.label, value=c.opener.id) for c in available],
        ),
    );
}

async def promptOpenNow(label: str) -> any {
    return await (await prompts()).confirm(rec(message=f"Open it now in {label}?", default=True));
}

async def confirmRemoveInteractively(workset: any) -> any {
    ask = await prompts();
    log(f"Workset '{workset.name}':");
    for row in formatMemberRows(workset.members) {
        log(f"  {row}");
    }
    return await ask.confirm(
        rec(
            message=f"Remove workset '{workset.name}'? (member folders are never touched)",
            default=False,
        ),
    );
}
