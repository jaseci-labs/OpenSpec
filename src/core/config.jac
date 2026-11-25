import from "node:path" { dirname }
import from "skills" { getSupportedAgents }

type AIToolOption = any;
type RetiredTool = any;

glob OPENSPEC_SKILL_NAMES: list[str] = [
         "openspec-explore",
         "openspec-new-change",
         "openspec-continue-change",
         "openspec-apply-change",
         "openspec-update-change",
         "openspec-ff-change",
         "openspec-sync-specs",
         "openspec-archive-change",
         "openspec-bulk-archive-change",
         "openspec-verify-change",
         "openspec-onboard",
         "openspec-propose",
         "openspec",
     ],
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
     ];

def findRetiredTool(toolId: str) -> any {
    return RETIRED_TOOLS.find(lambda (t: any) -> bool { t.id == toolId });
}

def formatRetiredToolError(tool: any) -> str {
    return f"{tool.name} is no longer supported: {tool.reason}. Set up {tool.successorName} instead: openspec init --tools {tool.successor}";
}

def:priv tool(name: str, value: str, skillsDir: str, label: str = "", **extra: any) -> any {
    return merge(
        rec(
            name=name, value=value, available=True, successLabel=label or name, skillsDir=skillsDir
        ),
        rec(**extra),
    );
}

glob:priv existingTools: list[any] = [
              tool("Amp", "amp", ".agents", detectionPaths=[".amp", ".agents/skills"]),
              tool(
                  "Antigravity",
                  "antigravity",
                  ".agents",
                  legacySkillsDirs=[".agent"],
                  detectionPaths=[".agent", ".agents/workflows"],
                  requiresIdeRestart=True,
              ),
              tool("AtomCode", "atomcode", ".atomcode"),
              tool("Auggie (Augment CLI)", "auggie", ".augment", "Auggie"),
              tool("IBM Bob", "bob", ".bob"),
              tool("Claude Code", "claude", ".claude"),
              tool("Cline", "cline", ".cline", requiresIdeRestart=True),
              tool("Command Code", "command-code", ".commandcode"),
              tool("CodeArts", "codeartsagent", ".codeartsdoer"),
              tool(
                  "Codex",
                  "codex",
                  ".agents",
                  legacySkillsDirs=[".codex"],
                  detectionPaths=[".agents/skills", ".codex/skills"],
              ),
              tool("DeepSeek Harness", "dsh", ".dsh"),
              tool(
                  "Devin Desktop (formerly Windsurf)",
                  "devin",
                  ".devin",
                  "Devin Desktop",
                  detectionPaths=[".devin", ".windsurf"],
                  requiresIdeRestart=True,
              ),
              tool("ForgeCode", "forgecode", ".forge"),
              tool("CodeBuddy Code (CLI)", "codebuddy", ".codebuddy", "CodeBuddy Code"),
              tool("Code Studio", "codestudio", ".codestudio", requiresIdeRestart=True),
              tool(
                  "Continue",
                  "continue",
                  ".continue",
                  "Continue (VS Code / JetBrains / Cli)",
                  requiresIdeRestart=True,
              ),
              tool("CoStrict", "costrict", ".cospec", requiresIdeRestart=True),
              tool("Crush", "crush", ".crush"),
              tool("Cursor", "cursor", ".cursor", requiresIdeRestart=True),
              tool("EasyCode", "easycode", ".easycode"),
              tool("Factory Droid", "factory", ".factory"),
              tool("Gemini CLI", "gemini", ".gemini"),
              tool(
                  "GitHub Copilot",
                  "github-copilot",
                  ".github",
                  detectionPaths=[
                      ".github/copilot-instructions.md",
                      ".github/instructions",
                      ".github/workflows/copilot-setup-steps.yml",
                      ".github/prompts",
                      ".github/agents",
                      ".github/skills",
                      ".github/.mcp.json",
                  ],
                  requiresIdeRestart=True,
              ),
              tool("GigaCode", "gigacode", ".gigacode"),
              tool("Grok Build", "grok", ".grok"),
              tool("GSD", "gsd", ".agents", detectionPaths=[".gsd"]),
              tool(
                  "Hermes Agent",
                  "hermes",
                  ".hermes",
                  detectionPaths=[".hermes", "HERMES.md", ".hermes.md"],
                  setupNote="Hermes loads this project's .hermes/skills only once you trust the repo: run `hermes skills trust` in this project (Hermes v2026.6.5 or later). On older versions, add this project's .hermes/skills directory to skills.external_dirs in ~/.hermes/config.yaml instead.",
              ),
              tool("iFlow", "iflow", ".iflow"),
              tool("Junie", "junie", ".junie", requiresIdeRestart=True),
              tool("Kilo Code", "kilocode", ".kilocode", requiresIdeRestart=True),
              tool("Kimi Code", "kimi", ".kimi-code", detectionPaths=[".kimi-code", ".kimi"]),
              tool("Kiro", "kiro", ".kiro", requiresIdeRestart=True),
              tool("Lingma", "lingma", ".lingma", requiresIdeRestart=True),
              tool("MiniMax Code", "minimax-code", ".minimax"),
              tool("Mistral Vibe", "vibe", ".vibe"),
              tool("Oh My Pi", "oh-my-pi", ".omp"),
              tool("OpenCode", "opencode", ".opencode"),
              tool("Pi", "pi", ".pi"),
              tool("SourceCraft Code Assistant", "codeassistant", ".codeassistant"),
              tool("Qoder", "qoder", ".qoder", requiresIdeRestart=True),
              tool("Qwen Code", "qwen", ".qwen"),
              tool(
                  "Rovo Dev CLI",
                  "rovodev",
                  ".rovodev",
                  detectionPaths=[".rovodev/skills", ".rovodev"],
              ),
              tool("Zoo Code", "roocode", ".roo", requiresIdeRestart=True),
              tool("Trae", "trae", ".trae", requiresIdeRestart=True),
              tool("Veai", "veai", ".veai"),
              tool("Warp", "warp", ".warp", detectionPaths=[".warp", "WARP.md"]),
              tool("Zed Agent", "zed", ".agents", detectionPaths=[".zed", ".agents/skills"]),
              tool("ZCode", "zcode", ".zcode"),
              tool(
                  "Other / Universal (shared .agents skills)",
                  "agents",
                  ".agents",
                  "shared .agents skills",
                  detectionPaths=[".agents/skills"],
                  searchAliases=[
                      "universal",
                      "other",
                      "generic",
                      "custom",
                      "proprietary",
                      "unlisted",
                      "unsupported",
                      "vendor-neutral",
                      "agents.md",
                  ],
              ),
          ],
          installerAliases: dict[str, str] = {
              "agents": "universal",
              "auggie": "augment",
              "claude": "claude-code",
              "codeartsagent": "codearts-agent",
              "factory": "droid",
              "gemini": "gemini-cli",
              "hermes": "hermes-agent",
              "iflow": "iflow-cli",
              "kilocode": "kilo",
              "kimi": "kimi-code-cli",
              "kiro": "kiro-cli",
              "qwen": "qwen-code",
              "roocode": "roo",
              "vibe": "mistral-vibe",
          },
          agents: list[any] = getSupportedAgents(),
          agentsById: dict[str, any] = {a.id: a for a in agents},
          existingIds: list[str] = [installerAgent(t.value).id for t in existingTools];

def installerAgent(toolId: str) -> any {
    return agentsById.get(installerAliases.get(toolId, toolId)) ?? agentsById["universal"];
}

def:priv byProjectFolder -> any {
    folders: any = new(globalThis.Map);
    for t in AI_TOOLS {
        agent = installerAgent(t.value);
        if not agent.universal {
            folders.set(
                agent.projectSkillsDir, [*(folders.get(agent.projectSkillsDir) ?? []), t.value]
            );
        }
    }
    return folders;
}

glob AI_TOOLS: any = [
         *[
             t
                 if installerAgent(t.value).id != "universal" or t.value == "agents"
                 else merge(
                     t,
                     rec(
                         setupNote="Skills are in the universal skills folder. If your tool needs its own folder, see https://github.com/Fission-AI/OpenSpec/blob/main/docs-lab/reference/supported-tools.md#link-another-tool",
                     ),
                 )
             for t in existingTools
         ],
         *[
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
     ],
     SKILL_LINKED_TOOL_IDS: any = new(
         globalThis.Set, [t.value for t in AI_TOOLS if not installerAgent(t.value).universal]
     ),
     agentsByProjectFolder: any = byProjectFolder(),
     UNIVERSAL_TOOL_ID: str = "agents",
     TOOL_ID_ALIASES: any = rec(windsurf="devin");

def getUniversalTool -> any {
    return AI_TOOLS.find(lambda (t: any) -> bool { t.value == UNIVERSAL_TOOL_ID });
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
