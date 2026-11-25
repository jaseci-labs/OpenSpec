import from "node:path" { dirname }

type AIToolOption = any;
type RetiredTool = any;

glob OPENSPEC_SKILL_NAMES: list[str] = "openspec-explore openspec-new-change openspec-continue-change openspec-apply-change openspec-update-change openspec-ff-change openspec-sync-specs openspec-archive-change openspec-bulk-archive-change openspec-verify-change openspec-onboard openspec-propose openspec".split(),
     OPENSPEC_MARKERS: any = rec(start="<!-- OPENSPEC:START -->", end="<!-- OPENSPEC:END -->"),
     RETIRED_TOOLS: any = [
         rec(
             id="amazon-q",
             name="Amazon Q Developer",
             folder=".amazonq",
             reason="it can't load skills, and AWS is retiring it in favor of Kiro",
             successor="kiro",
             successorName="Kiro",
         ),
     ],
     UNIVERSAL_TOOL_ID: str = "agents",
     TOOL_ID_ALIASES: any = rec(windsurf="devin");

glob:priv labels: dict[str, str] = {
              "auggie": "Auggie",
              "devin": "Devin Desktop",
              "codebuddy": "CodeBuddy Code",
              "continue": "Continue (VS Code / JetBrains / Cli)",
              "agents": "shared .agents skills",
          },
          legacyDirs: dict[str, str] = {"antigravity": ".agent", "codex": ".codex"},
          detection: dict[str, str] = {
              "amp": ".amp .agents/skills",
              "antigravity": ".agent .agents/workflows",
              "codex": ".agents/skills .codex/skills",
              "devin": ".devin .windsurf",
              "github-copilot": ".github/copilot-instructions.md .github/instructions .github/workflows/copilot-setup-steps.yml .github/prompts .github/agents .github/skills .github/.mcp.json",
              "gsd": ".gsd",
              "hermes": ".hermes HERMES.md .hermes.md",
              "kimi": ".kimi-code .kimi",
              "rovodev": ".rovodev/skills .rovodev",
              "warp": ".warp WARP.md",
              "zed": ".zed .agents/skills",
              "agents": ".agents/skills",
          },
          ideResident: list[str] = "antigravity cline devin codestudio continue costrict cursor github-copilot junie kilocode kiro lingma qoder roocode trae".split(),
          installerAliases: dict[str, str] = {
              pair.split("=")[0]: pair.split("=")[1]
              for pair in "agents=universal auggie=augment claude=claude-code codeartsagent=codearts-agent factory=droid gemini=gemini-cli hermes=hermes-agent iflow=iflow-cli kilocode=kilo kimi=kimi-code-cli kiro=kiro-cli qwen=qwen-code roocode=roo vibe=mistral-vibe".split()
          },
          agents: list[any] = need("skills").getSupportedAgents(),
          agentsById: dict[str, any] = {a.id: a for a in agents};

def findRetiredTool(toolId: str) -> any {
    return RETIRED_TOOLS.find(lambda (t: any) -> bool { t.id == toolId });
}

def formatRetiredToolError(tool: any) -> str {
    return f"{tool.name} is no longer supported: {tool.reason}. Set up {tool.successorName} instead: openspec init --tools {tool.successor}";
}

def installerAgent(toolId: str) -> any {
    return agentsById.get(installerAliases.get(toolId, toolId)) ?? agentsById["universal"];
}

def:priv tool(name: str, value: str, skillsDir: str) -> any {
    t = rec(
        name=name,
        value=value,
        available=True,
        successLabel=labels.get(value, name),
        skillsDir=skillsDir,
    );
    if value in legacyDirs {
        t.legacySkillsDirs = [legacyDirs[value]];
    }
    if value in detection {
        t.detectionPaths = detection[value].split();
    }
    if value == UNIVERSAL_TOOL_ID {
        t.searchAliases = "universal other generic custom proprietary unlisted unsupported vendor-neutral agents.md".split();
    } elif value == "hermes" {
        t.setupNote = "Hermes loads this project's .hermes/skills only once you trust the repo: run `hermes skills trust` in this project (Hermes v2026.6.5 or later). On older versions, add this project's .hermes/skills directory to skills.external_dirs in ~/.hermes/config.yaml instead.";
    } elif installerAgent(value).id == "universal" {
        t.setupNote = "Skills are in the universal skills folder. If your tool needs its own folder, see https://github.com/Fission-AI/OpenSpec/blob/main/docs-lab/reference/supported-tools.md#link-another-tool";
    }
    if value in ideResident {
        t.requiresIdeRestart = True;
    }
    return t;
}

glob:priv existingTools: list[any] = [
              tool(name, value, skillsDir)
              for (name, value, skillsDir) in [
                  ("Amp", "amp", ".agents"),
                  ("Antigravity", "antigravity", ".agents"),
                  ("AtomCode", "atomcode", ".atomcode"),
                  ("Auggie (Augment CLI)", "auggie", ".augment"),
                  ("IBM Bob", "bob", ".bob"),
                  ("Claude Code", "claude", ".claude"),
                  ("Cline", "cline", ".cline"),
                  ("Command Code", "command-code", ".commandcode"),
                  ("CodeArts", "codeartsagent", ".codeartsdoer"),
                  ("Codex", "codex", ".agents"),
                  ("DeepSeek Harness", "dsh", ".dsh"),
                  ("Devin Desktop (formerly Windsurf)", "devin", ".devin"),
                  ("ForgeCode", "forgecode", ".forge"),
                  ("CodeBuddy Code (CLI)", "codebuddy", ".codebuddy"),
                  ("Code Studio", "codestudio", ".codestudio"),
                  ("Continue", "continue", ".continue"),
                  ("CoStrict", "costrict", ".cospec"),
                  ("Crush", "crush", ".crush"),
                  ("Cursor", "cursor", ".cursor"),
                  ("EasyCode", "easycode", ".easycode"),
                  ("Factory Droid", "factory", ".factory"),
                  ("Gemini CLI", "gemini", ".gemini"),
                  ("GitHub Copilot", "github-copilot", ".github"),
                  ("GigaCode", "gigacode", ".gigacode"),
                  ("Grok Build", "grok", ".grok"),
                  ("GSD", "gsd", ".agents"),
                  ("Hermes Agent", "hermes", ".hermes"),
                  ("iFlow", "iflow", ".iflow"),
                  ("Junie", "junie", ".junie"),
                  ("Kilo Code", "kilocode", ".kilocode"),
                  ("Kimi Code", "kimi", ".kimi-code"),
                  ("Kiro", "kiro", ".kiro"),
                  ("Lingma", "lingma", ".lingma"),
                  ("MiniMax Code", "minimax-code", ".minimax"),
                  ("Mistral Vibe", "vibe", ".vibe"),
                  ("Oh My Pi", "oh-my-pi", ".omp"),
                  ("OpenCode", "opencode", ".opencode"),
                  ("Pi", "pi", ".pi"),
                  ("SourceCraft Code Assistant", "codeassistant", ".codeassistant"),
                  ("Qoder", "qoder", ".qoder"),
                  ("Qwen Code", "qwen", ".qwen"),
                  ("Rovo Dev CLI", "rovodev", ".rovodev"),
                  ("Zoo Code", "roocode", ".roo"),
                  ("Trae", "trae", ".trae"),
                  ("Veai", "veai", ".veai"),
                  ("Warp", "warp", ".warp"),
                  ("Zed Agent", "zed", ".agents"),
                  ("ZCode", "zcode", ".zcode"),
                  ("Other / Universal (shared .agents skills)", "agents", ".agents"),
              ]
          ],
          existingIds: list[str] = [installerAgent(t.value).id for t in existingTools];

glob AI_TOOLS: any = existingTools + [
         rec(
             value=a.id,
             name=a.name,
             available=True,
             successLabel=a.name,
             skillsDir=dirname(a.projectSkillsDir),
             detectionPaths=[a.projectSkillsDir],
         )
         for a in agents
         if a.id not in existingIds and a.id != "windsurf"
     ],
     SKILL_LINKED_TOOL_IDS: any = new(
         globalThis.Set, [t.value for t in AI_TOOLS if not installerAgent(t.value).universal]
     ),
     agentsByProjectFolder: any = new(globalThis.Map),
     toolsById: dict[str, any] = {};

with entry {
    for t in AI_TOOLS {
        if t.value not in toolsById {
            toolsById[t.value] = t;
        }
        agent = installerAgent(t.value);
        if not agent.universal {
            agentsByProjectFolder.set(
                agent.projectSkillsDir,
                [*(agentsByProjectFolder.get(agent.projectSkillsDir) ?? []), t.value],
            );
        }
    }
}

def findTool(toolId: str) -> any {
    return toolsById.get(toolId);
}

def getUniversalTool -> any {
    return findTool(UNIVERSAL_TOOL_ID);
}

def universalToolFallbackHint(offeredToolIds: list[str]) -> any {
    universal = getUniversalTool();
    if universal is None or universal.value not in offeredToolIds {
        return None;
    }
    return f"Tool not listed? Use --tools {universal.value}: the vendor-neutral target that writes {universal.skillsDir}/skills/ for any assistant.";
}

def resolveToolIdAlias(toolId: str) -> any {
    return TOOL_ID_ALIASES[toolId] ?? toolId;
}
