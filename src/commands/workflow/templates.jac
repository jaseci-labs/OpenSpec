import from "node:path" { default as path }
import from "node:process" { default as process }

type TemplatesOptions = any;

def:priv inside(child: str, parent: str) -> bool {
    rel: any = path.relative(parent, child);
    return not rel.startsWith("..") and not path.isAbsolute(rel);
}

def:priv templatePath(templatesDir: str, artifact: any) -> str {
    target = path.join(templatesDir, artifact.template);
    try {
        FileSystemUtils.assertPathWithin(templatesDir, target);
        return FileSystemUtils.canonicalizeExistingPath(target);
    } except Exception {
        raise new(
            globalThis.Error,
            f"Template '{artifact.template}' for artifact '{artifact.id}' points outside the schema templates directory",
        );
    }
}

async def templatesCommand(options: any) {
    import from "../../core/artifact-graph/resolver" { getProjectSchemasDir, getUserSchemasDir }
    spinner: any = None
        if options["json"]
        else (await load("ora")).default("Loading templates...").start();
    try {
        projectRoot = process.cwd();
        schemaName = validateSchemaExists(options["schema"] ?? DEFAULT_SCHEMA, projectRoot);
        g = ArtifactGraph.fromSchema(resolveSchema(schemaName, projectRoot));
        schemaDir = getSchemaDir(schemaName, projectRoot);
        source = "project"
            if inside(schemaDir, getProjectSchemasDir(projectRoot))
            else "user" if inside(schemaDir, getUserSchemasDir()) else "package";
        templatesDir = path.join(schemaDir, "templates");
        templates = [(a.id, templatePath(templatesDir, a)) for a in g.getAllArtifacts()];
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
        globalThis.console.log(
            globalThis.JSON.stringify(
                globalThis.Object.fromEntries([
                    [id, rec(path=p, source=source)]
                    for (id, p) in templates
                ]),
                None,
                2,
            ),
        );
        return;
    }
    globalThis.console.log(f"Schema: {schemaName}");
    globalThis.console.log(f"Source: {source}");
    globalThis.console.log();
    for (id, p) in templates {
        globalThis.console.log(f"{id}:");
        globalThis.console.log(f"  {p}");
    }
}
