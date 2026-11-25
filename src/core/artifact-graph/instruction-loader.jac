import from "node:fs" { default as fs }
import from "node:path" { default as path }

type ChangeContext = any;
type ArtifactInstructions = any;
type ChangeStatus = any;
type ArtifactStatus = any;
type DependencyInfo = any;
type ArtifactPathSummary = any;
type LoadChangeContextOptions = any;

glob:priv shownWarnings: set[str] = set();

glob SKIP_SPECS_INSTRUCTIONS_WARNING: str = "This change declares skip_specs: true in .openspec.yaml (no spec-level behavior changes), so this artifact is skipped.\nDo not create spec files - they will conflict with that marker. If requirements now change, remove skip_specs from .openspec.yaml and rerun this command.";

obj TemplateLoadError(globalThis.Error) {
    def init(message: str, templatePath: str) {
        super.init(message);
        self.templatePath = templatePath;
        self.name = "TemplateLoadError";
    }
}

def:priv messageOf(e: any) -> str {
    err = js_error(e);
    return err.message if globalThis.Error.prototype.isPrototypeOf(err) else globalThis.String(err);
}

def:priv skips(context: any, id: str) -> bool {
    skipped = context["skippedArtifacts"];
    return truthy(skipped) and skipped.has(id);
}

def loadTemplate(schemaName: str, templatePath: str, projectRoot: any = None) -> str {
    schemaDir = getSchemaDir(schemaName, projectRoot);
    if not schemaDir {
        raise TemplateLoadError(f"Schema '{schemaName}' not found", templatePath);
    }
    templatesDir = path.join(schemaDir, "templates");
    onDisk = path.join(templatesDir, templatePath);
    try {
        FileSystemUtils.assertPathWithin(templatesDir, onDisk);
    } except Exception as e {
        raise TemplateLoadError(messageOf(e), onDisk);
    }
    if not fs.existsSync(onDisk) {
        raise TemplateLoadError(f"Template not found: {onDisk}", onDisk);
    }
    fullPath = FileSystemUtils.canonicalizeExistingPath(onDisk);
    try {
        return fs.readFileSync(fullPath, "utf-8");
    } except Exception as e {
        raise TemplateLoadError(f"Failed to read template: {messageOf(e)}", fullPath);
    }
}

def loadChangeContext(
    projectRoot: str, changeName: str, schemaName: any = None, options: any = None
) -> any {
    changeDir = FileSystemUtils.canonicalizeExistingPath(
        at(options, "changeDir") ?? path.join(projectRoot, "openspec", "changes", changeName)
    );
    metadata = readChangeMetadata(changeDir, projectRoot);
    unknownKeys = readUnknownChangeMetadataKeys(changeDir);
    warnings = [formatUnknownChangeMetadataKeysMessage(unknownKeys)] if unknownKeys else [];
    resolvedSchemaName = resolveSchemaForChange(
        changeDir,
        schemaName,
        projectRoot,
        rec(metadata=metadata, projectConfig=at(options, "projectConfig")),
    );
    g = ArtifactGraph.fromSchema(resolveSchema(resolvedSchemaName, projectRoot));
    completed = detectCompleted(g, changeDir);
    skipped = new(globalThis.Set);
    if at(metadata, "skip_specs") {
        for a in g.getAllArtifacts() {
            if isSpecsArtifactPath(a.generates) and not completed.has(a.id) {
                completed.add(a.id);
                skipped.add(a.id);
            }
        }
    }
    home = at(options, "planningHome");
    return merge(
        rec(
            graph=g,
            completed=completed,
            schemaName=resolvedSchemaName,
            changeName=changeName,
            changeDir=changeDir,
            projectRoot=projectRoot,
        ),
        rec(planningHome=home) if truthy(home) else None,
        None if missing(metadata) else rec(metadata=metadata),
        rec(warnings=warnings) if warnings else None,
        rec(skippedArtifacts=skipped) if skipped.size > 0 else None,
    );
}

def generateInstructions(
    context: any, artifactId: str, projectRoot: any = None, options: any = None
) -> any {
    artifact = context.graph.getArtifact(artifactId);
    if not artifact {
        raise new(
            globalThis.Error, f"Artifact '{artifactId}' not found in schema '{context.schemaName}'"
        );
    }
    templateContent = loadTemplate(context.schemaName, artifact.template, context.projectRoot);
    effectiveRoot = projectRoot ?? context.projectRoot;
    projectConfig = at(options, "projectConfig") ?? JsNull;
    if at(options, "projectConfig") is None and effectiveRoot {
        try {
            projectConfig = readProjectConfig(effectiveRoot);
        } except Exception {}
    }
    rules = at(projectConfig, "rules");
    if truthy(rules) {
        validIds = new(
            globalThis.Set, [id for s in listSchemasWithInfo(effectiveRoot) for id in s.artifacts]
        );
        for warning in validateConfigRules(rules, validIds) {
            if warning not in shownWarnings {
                globalThis.console.warn(warning);
                shownWarnings.add(warning);
            }
        }
    }
    configContext: any = at(projectConfig, "context");
    configContext = (configContext.trim() if configContext else None) or None;
    artifactRules = rules[artifactId] if truthy(rules) and owns(rules, artifactId) else None;
    references = at(options, "references");
    return merge(
        rec(
            changeName=context.changeName,
            artifactId=artifact.id,
            schemaName=context.schemaName,
            changeDir=context.changeDir,
            planningHome=summarizePlanningHome(context["planningHome"]),
            outputPath=artifact.generates,
            resolvedOutputPath=resolveArtifactOutputPath(context.changeDir, artifact.generates),
            existingOutputPaths=resolveArtifactOutputs(context.changeDir, artifact.generates),
            description=artifact.description,
            instruction=artifact["instruction"],
            context=configContext,
            rules=artifactRules if truthy(artifactRules) and len(artifactRules) > 0 else None,
        ),
        None if references is None else rec(references=references),
        rec(warnings=context.warnings) if truthy(context["warnings"]) else None,
        rec(skipped=True, warning=SKIP_SPECS_INSTRUCTIONS_WARNING)
            if skips(context, artifact.id)
            else None,
        rec(
            template=templateContent,
            dependencies=[
                merge(
                    rec(
                        id=id,
                        done=context.completed.has(id),
                        path=at(context.graph.getArtifact(id), "generates") ?? id,
                        description=at(context.graph.getArtifact(id), "description") ?? "",
                    ),
                    rec(skipped=True) if skips(context, id) else None,
                )
                for id in artifact.requires
            ],
            unlocks=[a.id for a in context.graph.getAllArtifacts() if artifactId in a.requires],
        ),
    );
}

def formatChangeStatus(context: any, options: any = None) -> any {
    schema = resolveSchema(context.schemaName, context.projectRoot);
    applyRequires = at(schema, "apply", "requires") ?? [a.id for a in schema.artifacts];
    g = context.graph;
    completed = context.completed;
    ready = g.getNextArtifacts(completed);
    blocked = g.getBlocked(completed);
    artifactPaths = rec();
    statuses: list[any] = [];
    for a in g.getAllArtifacts() {
        artifactPaths[a.id] = rec(
            outputPath=a.generates,
            resolvedOutputPath=resolveArtifactOutputPath(context.changeDir, a.generates),
            existingOutputPaths=resolveArtifactOutputs(context.changeDir, a.generates),
        );
        status = "skipped"
            if skips(context, a.id)
            else "done" if completed.has(a.id) else "ready" if a.id in ready else "blocked";
        row = rec(id=a.id, outputPath=a.generates, status=status, requires=a.requires);
        if status == "blocked" {
            row.missingDeps = blocked[a.id] ?? [];
        }
        statuses.append(row);
    }
    order = {id: i for (i, id) in enumerate(g.getBuildOrder())};
    statuses = sorted(statuses, key=lambda (s: any) -> int { order.get(s.id, 0) });
    isComplete = g.isComplete(completed);
    storeId = at(options, "storeId");
    implementationRoot = at(options, "implementationRoot");
    return merge(
        rec(
            changeName=context.changeName,
            schemaName=context.schemaName,
            planningHome=summarizePlanningHome(context["planningHome"]),
            changeRoot=context.changeDir,
            artifactPaths=artifactPaths,
            isPlanningComplete=isComplete,
            isComplete=isComplete,
            applyRequires=applyRequires,
            nextSteps=buildNextSteps(
                merge(
                    rec(
                        changeName=context.changeName,
                        artifactStatuses=statuses,
                        allArtifactsComplete=isComplete,
                    ),
                    rec(storeId=storeId) if storeId else None,
                ),
            ),
            actionContext=buildActionContext(
                merge(
                    rec(projectRoot=context.projectRoot, artifactIds=[s.id for s in statuses]),
                    rec(
                        store=merge(
                            rec(id=storeId),
                            rec(implementationRoot=implementationRoot)
                                if implementationRoot
                                else None,
                        ),
                    )
                        if storeId
                        else None,
                ),
            ),
            artifacts=statuses,
        ),
        rec(warnings=context.warnings) if truthy(context["warnings"]) else None,
    );
}
