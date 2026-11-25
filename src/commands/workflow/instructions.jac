import from "node:fs" { default as fs }
import from "node:path" { default as path }

type InstructionsOptions = any;

glob:priv UNLIMITED: int = globalThis.Number.MAX_SAFE_INTEGER;

def:priv say(*lines: any) {
    for line in lines {
        globalThis.console.log(line);
    }
}

async def:priv loadRootConfig(found: any) -> tuple[any, any] {
    projectConfig = readProjectConfig(found.path);
    snapshot = await readRegistrySnapshot();
    declared = at(projectConfig, "references") ?? [];
    index = await assembleReferenceIndex(
        rec(references=declared, resolvedRoot=found, registryEntries=snapshot.entries)
    )
        if len(declared) > 0
        else [];
    return (projectConfig, index if len(index) > 0 else None);
}

async def:priv changeFor(found: any, options: any) -> str {
    return await validateChangeExists(
        options["change"],
        found.path,
        found.changesDir,
        rec(newChangeHint=withStoreFlag(found, "openspec new change <name>")),
    );
}

async def:priv runCommand(options: any, label: str, build: any, show: any) {
    found = await resolveRootForCommand(options, rec(json=options["json"]));
    if not truthy(found) {
        return;
    }
    spinner: any = None if options["json"] else (await load("ora")).default(label).start();
    try {
        result = await build(found);
    } except Exception as e {
        if spinner is not None {
            spinner.stop();
        }
        raise js_error(e);
    }
    if spinner is not None {
        spinner.stop();
    }
    if options["json"] {
        say(globalThis.JSON.stringify(merge(result, rec(root=toRootOutput(found))), None, 2));
        return;
    }
    show(result);
}

async def instructionsCommand(artifactId: any, options: any) {
    async def build(found: any) -> any {
        planningHome = toPlanningHome(found);
        changeName = await changeFor(found, options);
        if options["schema"] {
            validateSchemaExists(options.schema, found.path);
        }
        (projectConfig, references) = await loadRootConfig(found);
        context = loadChangeContext(
            found.path,
            changeName,
            options["schema"],
            rec(
                changeDir=getChangeDir(planningHome, changeName),
                planningHome=planningHome,
                projectConfig=projectConfig,
            ),
        );
        valid = "\n  ".join([a.id for a in context.graph.getAllArtifacts()]);
        if not artifactId {
            raise new(
                globalThis.Error,
                f"Missing required argument <artifact>. Valid artifacts:\n  {valid}",
            );
        }
        if not context.graph.getArtifact(artifactId) {
            raise new(
                globalThis.Error,
                f"Artifact '{artifactId}' not found in schema '{context.schemaName}'. Valid artifacts:\n  {valid}",
            );
        }
        return generateInstructions(
            context, artifactId, found.path, rec(projectConfig=projectConfig, references=references)
        );
    }
    await runCommand(options, "Generating instructions...", build, showInstructions);
}

def:priv showInstructions(instructions: any) {
    printInstructionsText(
        instructions, len([d for d in instructions.dependencies if not d.done]) > 0
    );
}

def printInstructionsText(instructions: any, isBlocked: bool) {
    i = instructions;
    say(
        f'<artifact id="{escapeEnvelopeAttribute(i.artifactId)}" change="{escapeEnvelopeAttribute(i.changeName)}" schema="{escapeEnvelopeAttribute(i.schemaName)}">',
        "",
    );
    for warning in i["warnings"] or [] {
        say("<warning>", escapeEnvelopeTags(warning), "</warning>", "");
    }
    if i["skipped"] {
        say(
            "<warning>",
            i["warning"] ?? "This artifact is skipped (skip_specs is set in .openspec.yaml).",
            "</warning>",
            "",
            "</artifact>",
        );
        return;
    }
    deps = i.dependencies;
    if isBlocked {
        say(
            "<warning>",
            "This artifact has unmet dependencies. Complete them first or proceed with caution.",
            f"Missing: {', '.join([d.id for d in deps if not d.done])}",
            "</warning>",
            "",
        );
    }
    say(
        "<task>",
        f'Create the {escapeEnvelopeTags(i.artifactId)} artifact for change "{escapeEnvelopeTags(i.changeName)}".',
        escapeEnvelopeTags(i.description),
        "</task>",
        "",
    );
    if i["context"] {
        say(
            "<project_context>",
            "<!-- This is background information for you. Do NOT include this in your output. -->",
            escapeEnvelopeTags(i.context),
            "</project_context>",
            "",
        );
    }
    if i["references"] {
        say(renderReferencedStoresBlock(i.references), "");
    }
    if i["rules"] {
        say(
            "<rules>",
            "<!-- These are constraints for you to follow. Do NOT include this in your output. -->",
            *[f"- {escapeEnvelopeTags(sanitizeInline(r, UNLIMITED))}" for r in i.rules],
            "</rules>",
            "",
        );
    }
    if deps {
        lines: list[any] = [
            "<dependencies>",
            "Read the current contents of these files before creating this artifact (re-read them from disk even if you saw them earlier - they may have been edited):",
            "",
        ];
        for d in deps {
            if d["skipped"] {
                lines.extend([
                    f'<dependency id="{d.id}" status="skipped">',
                    "  <description>Skipped: the change declares skip_specs, so this artifact has no files to read.</description>",
                    "</dependency>",
                ]);
                continue;
            }
            status = "done" if d.done else "missing";
            lines.extend([
                f'<dependency id="{d.id}" status="{status}">',
                f"  <path>{path.join(i.changeDir, d.path)}</path>",
                f"  <description>{escapeEnvelopeTags(d.description)}</description>",
                "</dependency>",
            ]);
        }
        say(*lines, "</dependencies>", "");
    }
    say("<output>", f"Write to: {i.resolvedOutputPath}", "</output>", "");
    if i["instruction"] {
        say("<instruction>", escapeEnvelopeTags(i.instruction.trim()), "</instruction>", "");
    }
    say(
        "<template>",
        "<!-- Use this as the structure for your output file. Fill in the sections. -->",
        escapeEnvelopeTags(i.template.trim()),
        "</template>",
        "",
        "<success_criteria>",
        "<!-- To be defined in schema validation rules -->",
        "</success_criteria>",
        "",
    );
    if i.unlocks {
        say(
            "<unlocks>",
            f"Completing this artifact enables: {', '.join(i.unlocks)}",
            "</unlocks>",
            "",
        );
    }
    say("</artifact>");
}

def:priv remedy(changeName: str, artifactId: any = None, many: bool = False) -> str {
    verb = "Create each with" if many else "Create it with";
    target = artifactId ?? "<artifact>";
    return f"{verb} `openspec instructions {target} --change {changeName}` (`openspec status --change {changeName}` shows what is left).";
}

def:priv artifactFor(schema: any, generates: any) -> any {
    ids = [a.id for a in schema.artifacts if a.generates == generates];
    return ids[0] if ids else None;
}

def:priv missingPrerequisites(
    required: list[any], schema: any, buildOrder: list[str], completed: any
) -> list[any] {
    byId = {a.id: a for a in schema.artifacts};
    queue: list[any] = [*required];
    seen = set(queue);
    absent: list[any] = [];
    while queue {
        id = queue.pop(0);
        if id not in byId {
            continue;
        }
        if not completed.has(id) {
            absent.append(id);
        }
        for dep in byId[id].requires {
            if dep not in seen {
                seen.add(dep);
                queue.append(dep);
            }
        }
    }
    order = {id: n for (n, id) in enumerate(buildOrder)};
    return sorted(absent, key=lambda (id: any) -> int { order.get(id, 0) });
}

def:priv hasOutputs(changeDir: str, artifacts: list[any]) -> bool {
    for a in artifacts {
        if len(resolveArtifactOutputs(changeDir, a.generates)) > 0 {
            return True;
        }
    }
    return False;
}

async def:priv applyWarnings(
    state: str, schema: any, changeDir: str, changeName: str, skipped: any
) -> list[any] {
    if state == "blocked" {
        return [];
    }
    specs = [a for a in schema.artifacts if isSpecsArtifactPath(a.generates)];
    if not specs or (truthy(skipped) and len([a for a in specs if skipped.has(a.id)]) > 0) {
        return [];
    }
    warnings: list[any] = [
        f"specs/{f.path} is not a capability's spec.md, so `openspec validate {changeName}` rejects it and archive never merges it. Move its requirements into specs/{f.expected}."
        for f in await findUnreadDeltaFiles(path.join(changeDir, "specs"))
    ];
    if hasOutputs(changeDir, specs) {
        return warnings;
    }
    target = specs[0].id if len(specs) == 1 else "<artifact-id>";
    warnings.append(
        f"This change has no delta specs and does not declare `skip_specs: true`, so `openspec validate {changeName}` fails on it. Write the delta specs before implementing (`openspec instructions {target} --change {changeName}`), or add `skip_specs: true` to {path.join(changeDir, METADATA_FILENAME)} if this change really changes no specified behavior.",
    );
    return warnings;
}

async def generateApplyInstructions(
    projectRoot: str, changeName: str, schemaName: any = None, options: any = None
) -> any {
    planningHome = at(options, "planningHome")
        ?? resolveCurrentPlanningHomeSync(rec(startPath=projectRoot));
    references = at(options, "references");
    projectConfig = at(options, "projectConfig");
    context = loadChangeContext(
        projectRoot,
        changeName,
        schemaName,
        rec(
            changeDir=getChangeDir(planningHome, changeName),
            planningHome=planningHome,
            projectConfig=projectConfig,
        ),
    );
    changeDir = context.changeDir;
    schema = resolveSchema(context.schemaName, projectRoot);
    required = at(schema, "apply", "requires") ?? [a.id for a in schema.artifacts];
    tracks: any = at(schema, "apply", "tracks");
    schemaInstruction: any = at(schema, "apply", "instruction");
    skipped = context["skippedArtifacts"];
    missingArtifacts: list[any] = [];
    for id in required {
        if truthy(skipped) and skipped.has(id) {
            continue;
        }
        found = [a for a in schema.artifacts if a.id == id];
        if found and len(resolveArtifactOutputs(changeDir, found[0].generates)) == 0 {
            missingArtifacts.append(id);
        }
    }
    prereqs = missingPrerequisites(
        [*required], schema, context.graph.getBuildOrder(), context.completed
    );
    contextFiles = rec();
    for a in schema.artifacts {
        outputs = resolveArtifactOutputs(changeDir, a.generates);
        if len(outputs) > 0 {
            contextFiles[a.id] = outputs;
        }
    }
    parsed: list[any] = [];
    unavailable: list[any] = [];
    tracksExists = False;
    if tracks {
        trackPaths = resolveArtifactOutputs(changeDir, tracks);
        tracksExists = len(trackPaths) > 0;
        for p in trackPaths {
            try {
                content = await fs.promises.readFile(p, "utf-8");
                parsed.extend([
                    merge(t, rec(sourcePath=p))
                    for t in parseLocatedTaskLines(content)
                ]);
            } except Exception as e {
                err = js_error(e);
                code = at(err, "code");
                message: any = err.message
                    if isinstance(err, globalThis.Error)
                    else globalThis.String(err);
                unavailable.append(
                    rec(
                        path=p,
                        reason=f"{code}: {message}"
                            if code and not message.includes(code)
                            else message,
                    ),
                );
            }
        }
    }
    tasks: list[any] = [];
    for t in parsed {
        if len(t.description) > 0 {
            tasks.append(
                rec(
                    id=f"{len(tasks) + 1}",
                    description=t.description,
                    done=t.done,
                    sourcePath=t.sourcePath,
                    line=t.line,
                ),
            );
        }
    }
    total = len(parsed);
    complete = len([t for t in parsed if t.done]);
    remaining = total - complete;
    tracksName = path.basename(tracks) if tracks else "";
    state = "blocked";
    if missingArtifacts {
        chain = f"\nNot created yet, in build order: {', '.join(prereqs)}. Build the ones this change needs before applying - the schema says which are conditional."
            if len(prereqs) > len(missingArtifacts)
            else "";
        instruction = f"Cannot apply this change yet. Missing artifacts: {', '.join(missingArtifacts)}.{chain}\n{remedy(changeName, prereqs[0] if len(prereqs) == 1 else None, len(prereqs) > 1)}";
    } elif tracks and not tracksExists {
        instruction = f"The {tracksName} file is missing and must be created.\n{remedy(changeName, artifactFor(schema, tracks))}";
    } elif tracks and unavailable and not tasks {
        instruction = "No readable task descriptions are available.";
    } elif tracks and not tasks {
        instruction = f"The {tracksName} file exists but contains no tasks to work on.\nAdd tasks to {tracksName}, or rebuild it: {remedy(changeName, artifactFor(schema, tracks))}";
    } elif tracks and not unavailable and remaining == 0 and total > 0 {
        state = "all_done";
        instruction = "All tracked tasks are complete.\nReview or verify the change as appropriate before archiving.";
    } else {
        state = "ready";
        instruction = schemaInstruction.trim()
            if not missing(schemaInstruction)
            else "Read context files, work through pending tasks, mark complete as you go.\nPause if you hit blockers or need clarification."
                if tracks
                else "All required artifacts complete. Proceed with implementation.";
    }
    if unavailable {
        instruction += "\nTask completion is not verified because tracking evidence was unavailable:\n"
            + "\n".join([f"- {f.path}: {f.reason}" for f in unavailable]);
    }
    warnings: list[any] = [*(context["warnings"] or [])];
    warnings.extend(await applyWarnings(state, schema, changeDir, changeName, skipped));
    return merge(
        rec(
            changeName=changeName,
            changeDir=changeDir,
            schemaName=context.schemaName,
            contextFiles=contextFiles,
            progress=rec(total=total, complete=complete, remaining=remaining),
            tasks=tasks,
            taskTrackingConfigured=not missing(tracks),
        ),
        rec(unavailableTrackingFiles=unavailable) if unavailable else None,
        rec(state=state, missingArtifacts=missingArtifacts or None),
        rec(missingPrerequisites=prereqs) if prereqs else None,
        rec(warnings=warnings) if warnings else None,
        rec(instruction=instruction),
        None if references is None else rec(references=references),
        loadOperationInputs(projectConfig ?? JsNull, "apply"),
    );
}

async def applyInstructionsCommand(options: any) {
    async def build(found: any) -> any {
        changeName = await changeFor(found, options);
        if options["schema"] {
            validateSchemaExists(options.schema, found.path);
        }
        (projectConfig, references) = await loadRootConfig(found);
        return await generateApplyInstructions(
            found.path,
            changeName,
            options["schema"],
            rec(
                planningHome=toPlanningHome(found),
                references=references,
                projectConfig=projectConfig,
            ),
        );
    }
    await runCommand(
        options, "Generating apply instructions...", build, printApplyInstructionsText
    );
}

def printApplyInstructionsText(instructions: any) {
    i = instructions;
    say(f"## Apply: {i.changeName}", f"Schema: {i.schemaName}", "");
    if i["references"] {
        say(renderReferencedStoresSection(i.references), "");
    }
    missingArtifacts = i["missingArtifacts"];
    if i.state == "blocked" and truthy(missingArtifacts) {
        say("### ⚠️ Blocked", "", f"Missing artifacts: {', '.join(missingArtifacts)}");
        prereqs = i["missingPrerequisites"];
        if prereqs and len(prereqs) > len(missingArtifacts) {
            say(f"Not created yet, in build order: {', '.join(prereqs)}");
        }
        say("");
    }
    if i["warnings"] {
        say("### ⚠️ Warnings", "", *[f"- {w}" for w in i.warnings], "");
    }
    files = globalThis.Object.entries(i.contextFiles);
    if files {
        say("### Context Files", *[f"- {e[0]}: {p}" for e in files for p in e[1]], "");
    }
    progress = i.progress;
    if progress.total > 0 or len(i.tasks) > 0 {
        mark = " ✓" if i.state == "all_done" else "";
        say("### Progress", f"{progress.complete}/{progress.total} complete{mark}", "");
    }
    if i.tasks {
        say("### Tasks", *[f"- {'[x]' if t.done else '[ ]'} {t.description}" for t in i.tasks], "");
    }
    say("### Instruction", i.instruction, "");
    printOperationInputsText(i);
}

def generateArchiveInstructions(changeName: str, projectConfig: any) -> any {
    return merge(rec(changeName=changeName), loadOperationInputs(projectConfig, "archive"));
}

async def archiveInstructionsCommand(options: any) {
    async def build(found: any) -> any {
        changeName = await changeFor(found, options);
        return generateArchiveInstructions(changeName, readProjectConfig(found.path));
    }
    await runCommand(options, "Loading archive inputs...", build, printArchiveInstructionsText);
}

def printArchiveInstructionsText(instructions: any) {
    say(f"## Archive Inputs: {instructions.changeName}", "");
    printOperationInputsText(instructions);
}

def:priv printOperationInputsText(inputs: any) {
    context = inputs["context"];
    guidance = inputs["operationGuidance"];
    if context {
        say("### Project Context (required instruction input)", context, "");
    }
    if guidance {
        say(
            "### Operation Guidance (advisory)",
            *[f"- {sanitizeInline(g, UNLIMITED)}" for g in guidance],
            "",
        );
    }
    if not context and not truthy(guidance) {
        say("No project context or operation guidance configured.");
    }
}
