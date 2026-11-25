import from "node:process" { default as process }

glob:priv FLAGS_OF: dict[str, list[str]] = {
    "change": ["deltasOnly", "requirementsOnly", "diff"],
    "spec": ["requirements", "scenarios", "requirement"],
};

def:priv logError(text: str) {
    globalThis.console.error(text);
}

def:priv choicesOf(ids: list[str]) -> list[any] {
    return [rec(name=id, value=id) for id in ids];
}

def:priv printJson(value: any) {
    globalThis.console.log(globalThis.JSON.stringify(value, JsNull, 2));
}

def:priv commandFor(kind_: str, root_: any) -> any {
    return ChangeCommand(root_.path) if kind_ == "change" else SpecCommand(root_.path);
}

def:priv delegateOptions(root_: any, options: any) -> any {
    return merge(options, rec(rootOutput=toRootOutput(root_)) if truthy(options["json"]) else None);
}

def:priv printNonInteractiveHint(root_: any) {
    logError("Nothing to show. Try one of:");
    logError(f"  {withStoreFlag(root_, 'openspec show <item>')}");
    if isStoreSelectedRoot(root_) {
        logError(f"  {withStoreFlag(root_, 'openspec show <item> --type change')}");
        logError(f"  {withStoreFlag(root_, 'openspec show <item> --type spec')}");
    } else {
        logError("  openspec change show");
        logError("  openspec spec show");
    }
    logError("Or run in an interactive terminal.");
}

def:priv warnIrrelevantFlags(kind_: str, options: any) {
    other = "spec" if kind_ == "change" else "change";
    irrelevant = [
        k
        for k in FLAGS_OF[other]
        if (options[k] is False if k == "scenarios" else owns(options, k))
    ];
    if irrelevant {
        logError(f"Warning: Ignoring flags not applicable to {kind_}: {', '.join(irrelevant)}");
    }
}

async def:priv runInteractiveByType(kind_: str, options: any, root_: any) {
    select = (await load("@inquirer/prompts")).select;
    ids = await (getActiveChangeIds(root_.path) if kind_ == "change" else getSpecIds(root_.path));
    if not ids {
        logError(f"No {kind_}s found.");
        process.exitCode = 1;
        return;
    }
    picked = await select(rec(message=f"Pick a {kind_}", choices=choicesOf(ids)));
    await commandFor(kind_, root_).show(picked, delegateOptions(root_, options));
}

async def:priv showDirect(itemName: str, typeOverride: any, options: any, root_: any) {
    changes: list[str] = await getActiveChangeIds(root_.path) if typeOverride != "spec" else [];
    specs: list[str] = await getSpecIds(root_.path) if typeOverride != "change" else [];
    (isChange, isSpec) = (itemName in changes, itemName in specs);
    resolved: any = typeOverride ?? ("change" if isChange else "spec" if isSpec else None);
    if resolved is None {
        suggestions = nearestMatches(itemName, changes + specs);
        message = f"Unknown item '{itemName}'. Did you mean: {', '.join(suggestions)}?"
            if suggestions
            else f"Unknown item '{itemName}'.";
        if truthy(options["json"]) {
            printJson(rec(status=[rec(severity="error", code="unknown_item", message=message)]));
        } else {
            logError(message);
        }
        process.exitCode = 1;
        return;
    }
    if typeOverride is None and isChange and isSpec {
        message = f"Ambiguous item '{itemName}' matches both a change and a spec.";
        if truthy(options["json"]) {
            printJson(
                rec(
                    status=[
                        rec(
                            severity="error",
                            code="ambiguous_item",
                            message=message,
                            fix="Pass --type change|spec.",
                        ),
                    ],
                ),
            );
        } else {
            logError(message);
            logError(
                "Pass --type change|spec."
                    if isStoreSelectedRoot(root_)
                    else "Pass --type change|spec, or use: openspec change show / openspec spec show",
            );
        }
        process.exitCode = 1;
        return;
    }
    warnIrrelevantFlags(resolved, options);
    await commandFor(resolved, root_).show(itemName, delegateOptions(root_, options));
}

obj ShowCommand(globalThis.Object) {
    async def execute(itemName: any = None, options: any = None) {
        options = options ?? rec();
        root_ = await resolveRootForCommand(options, rec(json=options["json"]));
        if not truthy(root_) {
            return;
        }
        if itemName {
            typeOverride: any = at(options, "type");
            typeOverride = typeOverride.toLowerCase() if typeOverride else None;
            await showDirect(
                itemName,
                typeOverride if typeOverride in ["change", "spec"] else None,
                options,
                root_,
            );
        } elif isInteractive(options) {
            kind_ = await (await load("@inquirer/prompts")).select(
                rec(
                    message="What would you like to show?",
                    choices=[rec(name="Change", value="change"), rec(name="Spec", value="spec")],
                ),
            );
            await runInteractiveByType(kind_, options, root_);
        } else {
            printNonInteractiveHint(root_);
            process.exitCode = 1;
        }
    }
}

with entry {
    jsAsync(ShowCommand, ["execute"]);
}
