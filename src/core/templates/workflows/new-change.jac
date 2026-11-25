glob ASK_WHAT_TO_BUILD: str = """   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.""";

def changeInput(cmd: bool, slash: str) -> str {
    if cmd {
        return f"**Input**: The argument after `{slash}` is the change name (kebab-case), OR a description of what the user wants to build.";
    }
    return "**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.";
}

def newChangeIntro(cmd: bool, slash: str) -> str {
    return f"""{STORE_SELECTION_GUIDANCE}

{PROJECT_ROOT_GUARD}

{changeInput(cmd, slash)}

**Steps**

1. **If no {"" if cmd else "clear "}input provided, ask what they want to build**

   Ask the user (open-ended, no preset options):
{ASK_WHAT_TO_BUILD}""";
}

def:priv body(cmd: bool) -> str {
    return f"""Start a new change using the experimental artifact-driven approach.

{newChangeIntro(cmd, "/opsx:new")}

2. **Determine the workflow schema**

   Use the default schema (omit `--schema`) unless the user explicitly requests a different workflow.

   **Use a different schema only if the user mentions:**
   - A specific schema name → use `--schema <name>`
   - "show workflows" or "what workflows" → run `openspec schemas --json` and let them choose

   **Otherwise**: Omit `--schema` to use the default.

3. **Create the change directory**
   ```bash
   openspec new change "<name>"
   ```
   Add `--schema <name>` only if the user requested a specific workflow.
   This creates a scaffolded change in the planning home resolved by the CLI.

4. **Show the artifact status**
   ```bash
   openspec status --change "<name>" --json
   ```
   Use the returned `planningHome`, `changeRoot`, `artifactPaths`, and `nextSteps` instead of assuming repo-local paths.

5. **Get instructions for the first artifact**
   The first artifact depends on the schema{". " if cmd else " (e.g., `proposal` for spec-driven).\n   "}Check the status output to find the first artifact with status "ready".
   ```bash
   openspec instructions <first-artifact-id> --change "<name>"
   ```
   This outputs the template and context for creating the first artifact.

6. **STOP and wait for user direction**

**Output**

After completing the steps, summarize:
- Change name and location
- Schema/workflow being used and its artifact sequence
- Current status (0/N artifacts complete)
- The template for the first artifact
- Prompt: "Ready to create the first artifact? {"Describe what this change should do and I’ll draft the first artifact" if cmd else "Just describe what this change is about and I'll draft it, or ask me to continue"}."

**Guardrails**
- Do NOT create any artifacts yet - just show the instructions
- Do NOT advance beyond showing the first artifact template
- If the name is invalid (not kebab-case), ask for a valid name
- If a change with that name already exists, {"ask whether to resume that change or start one with a different name" if cmd else "suggest continuing that change instead"}
- Pass --schema if using a non-default workflow""";
}

def getNewChangeSkillTemplate -> any {
    return rec(
        name="openspec-new-change",
        description='Start a new OpenSpec change using the experimental artifact workflow. Use when the user wants to create a new feature, fix, or modification with a structured step-by-step approach. Also use when the user says "openspec new change" or "opsx new".',
        instructions=body(False),
        license="MIT",
        compatibility="Requires openspec CLI.",
        metadata=rec(author="openspec", version="1.0"),
    );
}

def getOpsxNewCommandTemplate -> any {
    return rec(
        name="OPSX: New",
        description="Start a new change using the experimental artifact workflow (OPSX)",
        category="Workflow",
        tags=["workflow", "artifacts", "experimental"],
        content=body(True),
    );
}
