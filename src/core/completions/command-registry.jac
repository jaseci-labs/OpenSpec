def:priv compact(*pairs: any) -> any {
    return globalThis.Object.fromEntries([p for p in pairs if p[1] is not None]);
}

def:priv flag(name: str, description: str, value: any = None, short: any = None) -> any {
    return compact(
        ["name", name],
        ["short", short],
        ["description", description],
        ["takesValue", True if value else None],
        ["completionType", value if isinstance(value, str) else None],
        ["values", value if isinstance(value, list) else None],
    );
}

def:priv positional(spec: str) -> any {
    (name, _, of) = spec.partition(":");
    return compact(
        ["name", name.rstrip("?")],
        ["type", of or None],
        ["optional", True if name.endswith("?") else None],
    );
}

def:priv cmd(
    usage: str, description: str, flags: list[any], subcommands: any = None, typed: bool = True
) -> any {
    words = usage.split();
    positionals = [positional(w) for w in words[1:]];
    return compact(
        ["name", words[0]],
        ["description", description],
        ["acceptsPositional", True if positionals else None],
        ["positionalType", positionals[0]["type"] if positionals and typed else None],
        ["positionals", positionals or None],
        ["flags", flags],
        ["subcommands", subcommands],
    );
}

glob COMMAND_REGISTRY: any = [
    cmd(
        "init path?:path",
        "Initialize OpenSpec in your project",
        [
            flag(
                "tools",
                "Configure AI tools non-interactively (e.g., \"all\", \"none\", or comma-separated tool IDs)",
                True,
            ),
            flag("language", "Write new OpenSpec artifacts in this language", True),
            flag("force", "Auto-cleanup legacy files without prompting"),
            flag("profile", "Override global config profile (core or custom)", ["core", "custom"]),
            flag("no-animation", "Show a static welcome screen instead of the animated one"),
            flag(
                "copilot-cloud",
                "Generate GitHub Copilot cloud coding-agent files (opt-in; default: prompt)",
            ),
            flag("no-copilot-cloud", "Skip generating GitHub Copilot cloud coding-agent files"),
            flag(
                "scope",
                "Where the skills go: global (this machine, for every project) or project",
                ["global", "project"],
            ),
        ],
    ),
    cmd(
        "update path?:path",
        "Update OpenSpec instruction files",
        [
            flag("force", "Force update even when tools are up to date"),
            flag("dry-run", "Report what the update would change without writing anything"),
            flag("json", "With --dry-run, print the planned changes as JSON"),
        ],
    ),
    cmd(
        "install version?",
        "Install the standalone openspec, which runs without Node.js (latest release unless [version] is given)",
        [],
    ),
    cmd(
        "version",
        "Report the installed OpenSpec version and update availability",
        [COMMON_FLAGS.json, flag("check", "Check the registry for a newer version")],
    ),
    cmd(
        "list",
        "List items (changes by default, or specs with --specs)",
        [
            flag("specs", "List specs instead of changes"),
            flag("changes", "List changes explicitly (default)"),
            flag("archived", "Show only archived changes"),
            flag("all", "Show both active and archived changes"),
            flag("sort", "Sort order: \"recent\" (default) or \"name\"", ["recent", "name"]),
            COMMON_FLAGS.json,
            COMMON_FLAGS.store,
        ],
    ),
    cmd("view", "Display an interactive dashboard of specs and changes", [COMMON_FLAGS.store]),
    cmd(
        "validate item-name?:change-or-spec-id",
        "Validate changes and specs",
        [
            flag("all", "Validate all changes and specs"),
            flag("changes", "Validate all changes"),
            flag("specs", "Validate all specs"),
            flag(
                "archived",
                "Validate that archived changes have all tasks completed (for pre-commit linting)",
            ),
            flag("report", "Select bulk report content", ["full", "findings"]),
            COMMON_FLAGS["type"],
            COMMON_FLAGS.strict,
            COMMON_FLAGS.jsonValidation,
            flag(
                "concurrency",
                "Max concurrent validations (defaults to env OPENSPEC_CONCURRENCY or 6)",
                True,
            ),
            COMMON_FLAGS.noInteractive,
            COMMON_FLAGS.store,
        ],
    ),
    cmd(
        "show item-name?:change-or-spec-id",
        "Show a change or spec",
        [
            COMMON_FLAGS.json,
            COMMON_FLAGS["type"],
            COMMON_FLAGS.noInteractive,
            flag("deltas-only", "Show only deltas (JSON only, change-specific)"),
            flag("requirements-only", "Alias for --deltas-only (deprecated, change-specific)"),
            flag("diff", "Show per-requirement diffs for delta specs (change-specific)"),
            flag(
                "requirements",
                "Show only requirements, exclude scenarios (JSON only, spec-specific)",
            ),
            flag("no-scenarios", "Exclude scenario content (JSON only, spec-specific)"),
            flag(
                "requirement",
                "Show specific requirement by ID (JSON only, spec-specific)",
                True,
                short="r",
            ),
            COMMON_FLAGS.store,
        ],
    ),
    cmd(
        "archive change-name?:change-id",
        "Archive a completed change and update main specs",
        [
            flag("yes", "Skip confirmation prompts", short="y"),
            flag("skip-specs", "Skip spec update operations"),
            flag("no-validate", "Skip validation (not recommended)"),
            flag("json", "Output as JSON (non-interactive)"),
            COMMON_FLAGS.store,
        ],
    ),
    cmd(
        "status",
        "Display artifact completion status for a change",
        [
            flag("change", "Change name to show status for", True),
            flag("all", "Show status for all active changes"),
            flag("schema", "Schema override", True),
            COMMON_FLAGS.json,
            COMMON_FLAGS.store,
        ],
    ),
    cmd(
        "instructions artifact?",
        "Output enriched instructions for artifacts, apply, or archive",
        [
            flag("change", "Change name", True),
            flag("schema", "Schema override", True),
            COMMON_FLAGS.json,
            COMMON_FLAGS.store,
        ],
    ),
    cmd(
        "templates",
        "Show resolved template paths for all artifacts in a schema",
        [flag("schema", "Schema to use", True), COMMON_FLAGS.json],
    ),
    cmd(
        "schemas",
        "List available workflow schemas with descriptions",
        [COMMON_FLAGS.json, COMMON_FLAGS.store],
    ),
    cmd(
        "new",
        "Create new items",
        [],
        [
            cmd(
                "change name",
                "Create a new change directory",
                [
                    flag("description", "Description to add to README.md", True),
                    flag("goal", "Optional goal metadata to store with the change", True),
                    flag("schema", "Workflow schema to use", True),
                    COMMON_FLAGS.json,
                    COMMON_FLAGS.store,
                ],
            ),
        ],
    ),
    cmd(
        "store",
        "Create and manage stores - standalone OpenSpec repos you register on this machine",
        [],
        [
            cmd(
                "setup id?",
                "Create or register a local store",
                [
                    flag("path", "Directory to use for the store", "path"),
                    flag("init-git", "Initialize a Git repository in the store"),
                    flag("no-init-git", "Skip Git repository initialization"),
                    flag("remote", "Canonical clone source recorded in store.yaml", True),
                    COMMON_FLAGS.json,
                ],
            ),
            cmd(
                "register path?:path",
                "Register an existing store directory",
                [
                    flag("id", "Store id", True),
                    flag("yes", "Confirm creating store identity metadata"),
                    COMMON_FLAGS.json,
                ],
                typed=False,
            ),
            cmd(
                "unregister id",
                "Forget a local store registration without deleting files",
                [COMMON_FLAGS.json],
            ),
            cmd(
                "remove id",
                "Forget a local store registration and delete its local folder",
                [flag("yes", "Confirm local store folder deletion"), COMMON_FLAGS.json],
            ),
            cmd("list", "List registered stores", [COMMON_FLAGS.json]),
            cmd("ls", "List registered stores", [COMMON_FLAGS.json]),
            cmd("doctor id?", "Check local store registration and metadata", [COMMON_FLAGS.json]),
        ],
    ),
    cmd(
        "context",
        "Print the working context for the resolved OpenSpec root",
        [
            COMMON_FLAGS.json,
            COMMON_FLAGS.store,
            flag("code-workspace", "Also write a VS Code workspace file for the set", "path"),
            flag("force", "Overwrite an existing --code-workspace file"),
        ],
    ),
    cmd(
        "doctor",
        "Report relationship health for the resolved OpenSpec root",
        [COMMON_FLAGS.json, COMMON_FLAGS.store],
    ),
    cmd(
        "workset",
        "Compose, keep, and open personal working views (purely local)",
        [],
        [
            cmd(
                "create name?",
                "Compose and save a named working view of folders you choose",
                [
                    flag(
                        "member",
                        "Member folder as <path> or <name>=<path>; repeatable, first is the primary",
                        "path",
                    ),
                    flag("tool", "Preferred tool to open this workset with", True),
                    COMMON_FLAGS.json,
                ],
            ),
            cmd("list", "Show saved worksets with their members", [COMMON_FLAGS.json]),
            cmd("ls", "Show saved worksets with their members", [COMMON_FLAGS.json]),
            cmd(
                "open name",
                "Open a saved workset in your tool (editor window or agent session)",
                [flag("tool", "Open with this tool just this once", True)],
            ),
            cmd(
                "remove name",
                "Delete a saved workset (member folders are never touched)",
                [flag("yes", "Confirm removal non-interactively"), COMMON_FLAGS.json],
            ),
        ],
    ),
    cmd(
        "feedback message",
        "Submit feedback about OpenSpec",
        [flag("body", "Detailed description for the feedback", True)],
    ),
    cmd(
        "change",
        "Manage OpenSpec change proposals (deprecated)",
        [],
        [
            cmd(
                "show change-name?:change-id",
                "Show a change proposal",
                [
                    COMMON_FLAGS.json,
                    flag("deltas-only", "Show only deltas (JSON only)"),
                    flag("requirements-only", "Alias for --deltas-only (deprecated)"),
                    flag("diff", "Show per-requirement diffs for delta specs"),
                    COMMON_FLAGS.noInteractive,
                ],
            ),
            cmd(
                "list",
                "List all active changes (deprecated)",
                [COMMON_FLAGS.json, flag("long", "Show id and title with counts")],
            ),
            cmd(
                "validate change-name?:change-id",
                "Validate a change proposal",
                [COMMON_FLAGS.strict, COMMON_FLAGS.jsonValidation, COMMON_FLAGS.noInteractive],
            ),
        ],
    ),
    cmd(
        "spec",
        "Manage OpenSpec specifications",
        [],
        [
            cmd(
                "show spec-id?:spec-id",
                "Show a specification",
                [
                    COMMON_FLAGS.json,
                    flag("requirements", "Show only requirements, exclude scenarios (JSON only)"),
                    flag("no-scenarios", "Exclude scenario content (JSON only)"),
                    flag(
                        "requirement",
                        "Show specific requirement by ID (JSON only)",
                        True,
                        short="r",
                    ),
                    COMMON_FLAGS.noInteractive,
                ],
            ),
            cmd(
                "list",
                "List all specifications",
                [COMMON_FLAGS.json, flag("long", "Show id and title with counts")],
            ),
            cmd(
                "validate spec-id?:spec-id",
                "Validate a specification",
                [COMMON_FLAGS.strict, COMMON_FLAGS.jsonValidation, COMMON_FLAGS.noInteractive],
            ),
        ],
    ),
    cmd(
        "completion",
        "Manage shell completions for OpenSpec CLI",
        [],
        [
            cmd(
                "generate shell?:shell",
                "Generate completion script for a shell (outputs to stdout)",
                [],
            ),
            cmd(
                "install shell?:shell",
                "Install completion script for a shell",
                [flag("verbose", "Show detailed installation output")],
            ),
            cmd(
                "uninstall shell?:shell",
                "Uninstall completion script for a shell",
                [flag("yes", "Skip confirmation prompts", short="y")],
            ),
        ],
    ),
    cmd(
        "config",
        "View and modify global OpenSpec configuration",
        [flag("scope", "Config scope (only \"global\" supported currently)", ["global"])],
        [
            cmd("path", "Show config file location", []),
            cmd("list", "Show all current settings", [COMMON_FLAGS.json]),
            cmd("get key", "Get a specific value (raw, scriptable)", []),
            cmd(
                "set key value",
                "Set a value (auto-coerce types)",
                [
                    flag("string", "Force value to be stored as string"),
                    flag("allow-unknown", "Allow setting unknown keys"),
                ],
            ),
            cmd("unset key", "Remove a key (revert to default)", []),
            cmd(
                "reset",
                "Reset configuration to defaults",
                [
                    flag("all", "Reset all configuration (required)"),
                    flag("yes", "Skip confirmation prompts", short="y"),
                ],
            ),
            cmd("edit", "Open config in $EDITOR", []),
            cmd(
                "profile preset?",
                "Configure workflow profile (interactive picker or preset shortcut)",
                [],
            ),
        ],
    ),
    cmd(
        "schema",
        "Manage workflow schemas",
        [],
        [
            cmd(
                "which name?:schema-name",
                "Show where a schema resolves from",
                [COMMON_FLAGS.json, flag("all", "List all schemas with their resolution sources")],
            ),
            cmd(
                "validate name?:schema-name",
                "Validate a schema structure and templates",
                [COMMON_FLAGS.json, flag("verbose", "Show detailed validation steps")],
            ),
            cmd(
                "fork source:schema-name name?",
                "Copy an existing schema to project for customization",
                [COMMON_FLAGS.json, flag("force", "Overwrite existing destination")],
            ),
            cmd(
                "init name",
                "Create a new project-local schema",
                [
                    COMMON_FLAGS.json,
                    flag("description", "Schema description", True),
                    flag("artifacts", "Comma-separated artifact IDs", True),
                    flag("default", "Set as project default schema"),
                    flag("no-default", "Do not prompt to set as default"),
                    flag("force", "Overwrite existing schema"),
                ],
            ),
        ],
    ),
];
