import from "node:fs" { existsSync, readFileSync }
import from "node:path" { default as path }
import from "node:process" { default as process }

type ShowOptions = any;

glob:priv SPECS_DIR: str = "openspec/specs";

def:priv assertSpecPath(specsDir: str, specPath: str) {
    relativePath: str = path.relative(path.resolve(specsDir), path.resolve(specPath));
    if relativePath == ".."
        or relativePath.startswith(f"..{path.sep}")
        or path.isAbsolute(relativePath)
    {
        raise new(globalThis.Error, f"Path is outside the allowed directory: {specPath}");
    }
    assertDiscoveredSpecFile(specsDir, specPath);
}

def:priv parseSpecFromFile(specsDir: str, specPath: str, specId: str) -> any {
    assertSpecPath(specsDir, specPath);
    return MarkdownParser(readFileSync(specPath, "utf-8")).parseSpec(specId);
}

def:priv metadataOf(spec: any) -> any {
    return spec["metadata"] ?? rec(version="1.0.0", format="openspec");
}

def:priv filterRequirements(spec: any, options: any) -> list[any] {
    requirements: any = spec.requirements;
    wanted = at(options, "requirement");
    if truthy(wanted) {
        index = globalThis.Number.parseInt(wanted, 10);
        if not globalThis.Number.isInteger(index) or index < 1 or index > len(requirements) {
            raise new(globalThis.Error, f"Requirement {wanted} not found");
        }
        requirements = [requirements[index - 1]];
    }
    withScenarios = at(options, "scenarios") is not False
        and not truthy(at(options, "requirements"));
    return [
        rec(name=r.name, text=r.text, scenarios=r.scenarios if withScenarios else [])
        for r in requirements
    ];
}

async def:priv pickSpec(message: str, base: any, options: any) -> str {
    specIds = await getSpecIds(base);
    if not isInteractive(options) or not specIds {
        raise new(globalThis.Error, "Missing required argument <spec-id>");
    }
    return await (await load("@inquirer/prompts")).select(
        rec(message=message, choices=[rec(name=id, value=id) for id in specIds])
    );
}

def:priv reportFailure(error: any) {
    err = js_error(error);
    globalThis.console.error(
        f"Error: {err.message if globalThis.Error.prototype.isPrototypeOf(err) else 'Unknown error'}",
    );
    process.exitCode = 1;
}

def:priv printJson(value: any) {
    globalThis.console.log(globalThis.JSON.stringify(value, JsNull, 2));
}

obj SpecCommand(globalThis.Object) {
    def init(rootPath: any = None) {
        super.init();
        self.rootPath = rootPath;
        self.specsDir = path.join(rootPath, "openspec", "specs") if truthy(rootPath) else SPECS_DIR;
    }

    async def show(specId: any = None, options: any = None) {
        if not specId {
            specId = await pickSpec(
                "Select a spec to show", self.rootPath ?? process.cwd(), options
            );
        }
        specPath = path.join(self.specsDir, specId, "spec.md");
        assertSpecPath(self.specsDir, specPath);
        if not existsSync(specPath) {
            shown = specPath if truthy(self.rootPath) else f"openspec/specs/{specId}/spec.md";
            raise new(globalThis.Error, f"Spec '{specId}' not found at {shown}");
        }
        if not truthy(at(options, "json")) {
            assertSpecPath(self.specsDir, specPath);
            globalThis.console.log(readFileSync(specPath, "utf-8"));
            return;
        }
        if truthy(options["requirements"]) and truthy(options["requirement"]) {
            raise new(
                globalThis.Error, "Options --requirements and --requirement cannot be used together"
            );
        }
        parsed = parseSpecFromFile(self.specsDir, specPath, specId);
        requirements = filterRequirements(parsed, options);
        printJson(
            merge(
                rec(
                    id=specId,
                    title=parsed.name,
                    overview=parsed.overview,
                    requirementCount=len(requirements),
                    requirements=requirements,
                    metadata=metadataOf(parsed),
                ),
                rec(root=options.rootOutput) if truthy(options["rootOutput"]) else None,
            ),
        );
    }
}

with entry {
    jsAsync(SpecCommand, ["show"]);
}

async def specShowCommand(specId: any, options: any) {
    try {
        await SpecCommand().show(specId, options);
    } except Exception as e {
        reportFailure(e);
    }
}

async def specListCommand(options: any) {
    try {
        if not existsSync(SPECS_DIR) {
            globalThis.console.log("No items found");
            return;
        }
        specs: list[any] = [];
        for d in await discoverSpecFiles(SPECS_DIR) {
            try {
                spec = parseSpecFromFile(SPECS_DIR, d.specFile, d.id);
                specs.append(
                    rec(id=d.id, title=spec.name, requirementCount=len(spec.requirements))
                );
            } except Exception {
                specs.append(rec(id=d.id, title=d.id, requirementCount=0));
            }
        }
        specs = globalThis.Array.prototype.sort.call(
            specs, lambda (a: any, b: any) -> int { a.id.localeCompare(b.id) }
        );
        if truthy(at(options, "json")) {
            printJson(specs);
        } elif not specs {
            globalThis.console.log("No items found");
        } else {
            for s in specs {
                globalThis.console.log(
                    f"{s.id}: {s.title} [requirements {s.requirementCount}]"
                        if truthy(at(options, "long"))
                        else s.id,
                );
            }
        }
    } except Exception as e {
        reportFailure(e);
    }
}

async def specValidateCommand(specId: any, options: any) {
    try {
        if not specId {
            specId = await pickSpec("Select a spec to validate", None, options);
        }
        specPath = path.join(SPECS_DIR, specId, "spec.md");
        assertSpecPath(SPECS_DIR, specPath);
        if not existsSync(specPath) {
            raise new(
                globalThis.Error, f"Spec '{specId}' not found at openspec/specs/{specId}/spec.md"
            );
        }
        assertSpecPath(SPECS_DIR, specPath);
        result = await Validator(at(options, "strict")).validateSpec(specPath);
        if truthy(at(options, "json")) {
            printJson(result);
        } elif result.valid {
            globalThis.console.log(f"Specification '{specId}' is valid");
        } else {
            globalThis.console.error(f"Specification '{specId}' has issues");
            for i in result.issues {
                prefix = {"ERROR": "✗", "WARNING": "⚠"}.get(i.level, "ℹ");
                globalThis.console.error(f"{prefix} [{i.level}] {i.path}: {i.message}");
            }
        }
        process.exitCode = 0 if result.valid else 1;
    } except Exception as e {
        reportFailure(e);
    }
}
