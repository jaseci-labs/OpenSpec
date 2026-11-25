graph layers {
    layer all { *; }
}

graph spaces {
    space openspec: node { "."; }
}

graph import {
    src.host ++> "src/core/converters/json-converter" { merge, rec }
    "src/core/parsers/markdown-parser" ++> "src/core/converters/json-converter" { MarkdownParser }
    "src/core/parsers/change-parser" ++> "src/core/converters/json-converter" { ChangeParser }
    "src/utils/file-system" ++> "src/core/converters/json-converter" { FileSystemUtils }
    src.host ++> "src/core/shared/skill-links" { kind, missing, rec }
    "src/core/shared/generated-fingerprint" ++> "src/core/shared/skill-links" {
        isReleasedGeneratedContent,
        normalizeGeneratedContent,
    }
    "src/core/file-view" ++> "src/core/shared/skill-links" { DISK_VIEW }
    src.host ++> "src/core/parsers/change-parser" { at, found, merge, rec, sub, truthy }
    "src/core/parsers/markdown-parser" ++> "src/core/parsers/change-parser" { MarkdownParser }
    "src/core/parsers/requirement-blocks" ++> "src/core/parsers/change-parser" { parseDeltaSpec }
    "src/utils/spec-discovery" ++> "src/core/parsers/change-parser" { discoverSpecFiles }
    src.lazy ++> src.commands.feedback { need, packageRoot }
    src.host ++> "src/commands/install-standalone" { JsNull, at, found, merge, missing, rec, sub }
    src.lazy ++> "src/commands/install-standalone" { pick }
    "src/utils/executable-path" ++> "src/commands/install-standalone" { findCopiesOnPath, samePath }
    "src/core/version-check" ++> "src/commands/install-standalone" {
        getCliInstallInfo,
        getStandaloneBinaryPath,
    }
    src.host ++> "src/core/version-check" {
        JsNull,
        at,
        found,
        js_error,
        kind,
        merge,
        missing,
        rec,
        rx,
        same,
        sub,
        truthy,
    }
    src.lazy ++> "src/core/version-check" { load, need, packageRoot, pick }
    src.utils.ci ++> "src/core/version-check" { isCiEnvironment }
    "src/telemetry/opt-out" ++> "src/core/version-check" { isTelemetryOptedOutByEnv }
    "src/utils/file-system" ++> "src/core/version-check" { FileSystemUtils }
    "src/core/global-config" ++> "src/core/version-check" {
        getGlobalConfig,
        isGlobalConfigUnreadable,
    }
    "src/utils/executable-path" ++> "src/core/version-check" { findCopiesOnPath, samePath }
    src.host ++> "src/core/openspec-root" { JsNull, at, js_error, rec }
    "src/utils/file-system" ++> "src/core/openspec-root" { FileSystemUtils }
    "src/core/config-prompts" ++> "src/core/openspec-root" { serializeConfig }
    src.core.store.errors ++> "src/core/openspec-root" { makeStoreDiagnostic }
    src.host ++> "src/core/known-projects" { at, js_error, kind, found, rec }
    "src/core/project-dir" ++> "src/core/known-projects" { OPENSPEC_DIR_NAME }
    "src/core/global-config" ++> "src/core/known-projects" { getGlobalDataDir }
    src.host ++> "src/core/completion-tip" { JsNull, at, kind, merge, missing, rec, same }
    "src/core/global-config" ++> "src/core/completion-tip" { getGlobalConfigPath }
    "src/core/file-state" ++> "src/core/completion-tip" { writeFileAtomically }
    src.utils.ci ++> "src/core/completion-tip" { isCiEnvironment }
    "src/utils/shell-detection" ++> "src/core/completion-tip" { detectShell }
    src.core.completions.factory ++> "src/core/completion-tip" { CompletionFactory }
    src.host ++> src.core.completions.factory { at, js_error, merge, rec, sub }
    "src/utils/file-system" ++> src.core.completions.factory { FileSystemUtils }
    "src/core/completions/generators/zsh-generator" ++> src.core.completions.factory {
        ZshGenerator,
    }
    "src/core/completions/generators/bash-generator" ++> src.core.completions.factory {
        BashGenerator,
    }
    "src/core/completions/generators/fish-generator" ++> src.core.completions.factory {
        FishGenerator,
    }
    "src/core/completions/generators/powershell-generator" ++> src.core.completions.factory {
        PowerShellGenerator,
    }
    "src/core/completions/installers/zsh-installer" ++> src.core.completions.factory {
        ZshInstaller,
    }
    "src/core/completions/installers/bash-installer" ++> src.core.completions.factory {
        BashInstaller,
    }
    "src/core/completions/installers/fish-installer" ++> src.core.completions.factory {
        FishInstaller,
    }
    "src/core/completions/installers/powershell-installer" ++> src.core.completions.factory {
        PowerShellInstaller,
    }
    src.host ++> "src/core/completions/installers/fish-installer" { rec }
    src.core.completions.factory ++> "src/core/completions/installers/fish-installer" {
        UP_TO_DATE,
        backupFile,
        failed,
        isScriptFile,
        jsAsync,
        placeScript,
        uninstallScript,
    }
    src.host ++> "src/core/completions/installers/bash-installer" { rec }
    "src/core/completions/installers/shell-quote" ++> "src/core/completions/installers/bash-installer" {
        shellSingleQuote,
    }
    src.core.completions.factory ++> "src/core/completions/installers/bash-installer" {
        UP_TO_DATE,
        backupFile,
        configureRc,
        failed,
        isScriptFile,
        jsAsync,
        placeScript,
        removeRcBlock,
        uninstallScript,
    }
    src.host ++> "src/core/completions/installers/powershell-installer" { at, js_error, rec }
    src.core.completions.factory ++> "src/core/completions/installers/powershell-installer" {
        END_MARKER,
        START_MARKER,
        UP_TO_DATE,
        backupFile,
        ensureWritable,
        failed,
        isScriptFile,
        jsAsync,
        placeScript,
        uninstallScript,
    }
    src.host ++> "src/core/completions/installers/zsh-installer" { rec }
    "src/core/completions/installers/shell-quote" ++> "src/core/completions/installers/zsh-installer" {
        shellSingleQuote,
    }
    src.core.completions.factory ++> "src/core/completions/installers/zsh-installer" {
        END_MARKER,
        START_MARKER,
        UP_TO_DATE,
        backupFile,
        configureRc,
        failed,
        jsAsync,
        placeScript,
        removeRcBlock,
    }
    src.host ++> "src/core/completions/generators/fish-generator" { truthy }
    "src/core/completions/templates/fish-templates" ++> "src/core/completions/generators/fish-generator" {
        FISH_DYNAMIC_HELPERS,
        FISH_STATIC_HELPERS,
    }
    src.host ++> "src/core/completions/generators/powershell-generator" { sub }
    "src/core/completions/templates/powershell-templates" ++> "src/core/completions/generators/powershell-generator" {
        POWERSHELL_DYNAMIC_HELPERS,
    }
    "src/core/completions/templates/zsh-templates" ++> "src/core/completions/generators/zsh-generator" {
        ZSH_DYNAMIC_HELPERS,
    }
    src.host ++> "src/core/completions/generators/bash-generator" { sub }
    "src/core/completions/templates/bash-templates" ++> "src/core/completions/generators/bash-generator" {
        BASH_DYNAMIC_HELPERS,
    }
    src.host ++> "src/core/legacy-cleanup" {
        at,
        found,
        js_error,
        merge,
        missing,
        rec,
        rx,
        same,
        sub,
        truthy,
    }
    src.lazy ++> "src/core/legacy-cleanup" { pick }
    "src/utils/file-system" ++> "src/core/legacy-cleanup" {
        FileSystemUtils,
        removeMarkerBlock as removeMarkerBlockUtil,
    }
    src.core.config ++> "src/core/legacy-cleanup" { OPENSPEC_MARKERS, findRetiredTool }
    "src/core/shared/generated-fingerprint" ++> "src/core/legacy-cleanup" {
        hasReleasedOpenSpecBlock,
        isReleasedGeneratedContent,
    }
    src.core.profiles ++> "src/core/legacy-cleanup" { ALL_WORKFLOWS }
    src.host ++> "src/core/templates/workflows/apply-change" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/apply-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/apply-change" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/templates/workflows/archive-change" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/archive-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/archive-change" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/shared-skill-target" { at, kind, rec, rx, sub }
    src.core.config ++> "src/core/shared-skill-target" {
        AI_TOOLS,
        OPENSPEC_SKILL_NAMES,
        resolveToolIdAlias,
    }
    "src/utils/file-system" ++> "src/core/shared-skill-target" { FileSystemUtils }
    "src/core/file-view" ++> "src/core/shared-skill-target" { DISK_VIEW }
    "src/core/shared/generated-fingerprint" ++> "src/core/shared-skill-target" {
        isReleasedGeneratedContent,
    }
    "src/core/shared/skill-paths" ++> "src/core/shared-skill-target" {
        SHARED_SKILLS_ROOT,
        resolveFormerOwnSkillsDir,
    }
    src.host ++> "src/core/shared/skill-content-equivalence" { sub }
    src.core.config ++> "src/core/shared/skill-content-equivalence" { OPENSPEC_SKILL_NAMES }
    "src/core/shared/generated-fingerprint" ++> "src/core/shared/skill-content-equivalence" {
        isReleasedGeneratedContent,
        normalizeGeneratedContent,
    }
    src.host ++> "src/core/shared/generated-fingerprint" { found, matchOf, sub }
    "src/core/shared/released-generated-fingerprints" ++> "src/core/shared/generated-fingerprint" {
        RELEASED_GENERATED_FINGERPRINTS,
    }
    "src/utils/file-system" ++> "src/core/shared/generated-fingerprint" { findMarkerBlock }
    src.host ++> src.core.templates.workflows.explore { rec }
    "src/core/templates/workflows/store-selection" ++> src.core.templates.workflows.explore {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> src.core.templates.workflows.explore {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> src.core.templates.workflows.propose { rec }
    "src/core/templates/workflows/store-selection" ++> src.core.templates.workflows.propose {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> src.core.templates.workflows.propose {
        PROJECT_ROOT_GUARD,
    }
    "src/core/templates/workflows/new-change" ++> src.core.templates.workflows.propose {
        changeInput,
        ASK_WHAT_TO_BUILD,
    }
    "src/core/templates/workflows/ff-change" ++> src.core.templates.workflows.propose {
        artifactBuildSteps,
    }
    src.host ++> "src/core/templates/workflows/ff-change" { rec }
    "src/core/templates/workflows/new-change" ++> "src/core/templates/workflows/ff-change" {
        newChangeIntro,
    }
    src.host ++> src.core.templates.workflows.onboard { rec }
    "src/core/templates/workflows/store-selection" ++> src.core.templates.workflows.onboard {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> src.core.templates.workflows.onboard {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/templates/workflows/new-change" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/new-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/new-change" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/templates/workflows/verify-change" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/verify-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/verify-change" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/templates/workflows/update-change" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/update-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/update-change" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/templates/workflows/sync-specs" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/sync-specs" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/sync-specs" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/templates/workflows/continue-change" { rec }
    "src/core/templates/workflows/store-selection" ++> "src/core/templates/workflows/continue-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" ++> "src/core/templates/workflows/continue-change" {
        PROJECT_ROOT_GUARD,
    }
    src.host ++> "src/core/project-skills-scope" { JsNull, at }
    src.lazy ++> "src/core/project-skills-scope" { need }
    "src/utils/file-system" ++> "src/core/project-skills-scope" { FileSystemUtils }
    "src/core/project-config" ++> "src/core/project-skills-scope" {
        readProjectConfig,
        resolveConfigFilePath,
    }
    src.host ++> "src/core/project-config" {
        JsNull,
        at,
        js_error,
        kind,
        merge,
        missing,
        rec,
        truthy,
    }
    src.lazy ++> "src/core/project-config" { need }
    src.core.store.foundation ++> "src/core/project-config" { getStoreMetadataPath }
    src.host ++> src.core.store.foundation { JsNull, at, js_error, merge, rec, truthy }
    src.lazy ++> src.core.store.foundation { need }
    src.core.id ++> src.core.store.foundation {
        KEBAB_ID_DESCRIPTION,
        KEBAB_ID_FIX,
        folderStyleNameProblem,
        isKebabId,
    }
    "src/core/global-config" ++> src.core.store.foundation { getGlobalDataDir }
    "src/utils/file-system" ++> src.core.store.foundation { FileSystemUtils }
    "src/core/file-state" ++> src.core.store.foundation {
        acquireFileLock,
        isNodeErrorCode,
        makeLockErrorFactory,
        pathIsDirectory,
        pathIsFile,
        releaseFileLock,
        writeFileAtomically,
    }
    "src/core/zod-issues" ++> src.core.store.foundation { formatZodIssues }
    src.core.store.errors ++> src.core.store.foundation { StoreError }
    src.host ++> "src/core/parsers/markdown-parser" { JsNull, found, matchOf, rec, sub }
    "src/core/parsers/requirement-text" ++> "src/core/parsers/markdown-parser" {
        buildCodeFenceMask,
        extractRequirementText,
        hasScenarioBody,
    }
    "src/core/parsers/requirement-blocks" ++> "src/core/parsers/markdown-parser" {
        normalizeRequirementName,
        scenarioNameFromHeaderText,
        stripClosingSequence,
    }
    src.lazy ++> "src/core/artifact-graph/resolver" { packageRoot }
    src.host ++> "src/core/artifact-graph/resolver" { JsNull, found, js_error, rec, sub }
    "src/core/global-config" ++> "src/core/artifact-graph/resolver" { getGlobalDataDir }
    "src/utils/file-system" ++> "src/core/artifact-graph/resolver" { FileSystemUtils }
    "src/core/artifact-graph/schema" ++> "src/core/artifact-graph/resolver" { parseSchema }
    src.host ++> src.core.worksets { JsNull, at, js_error, merge, rec }
    src.lazy ++> src.core.worksets { need }
    "src/core/global-config" ++> src.core.worksets { getGlobalDataDir }
    "src/utils/file-system" ++> src.core.worksets { FileSystemUtils }
    "src/core/file-state" ++> src.core.worksets {
        acquireFileLock,
        makeLockErrorFactory,
        pathIsFile,
        releaseFileLock,
        writeFileAtomically,
    }
    src.core.store.errors ++> src.core.worksets { StoreError }
    src.core.id ++> src.core.worksets {
        KEBAB_ID_DESCRIPTION,
        KEBAB_ID_FIX,
        folderStyleNameProblem,
        isKebabId,
    }
    "src/core/zod-issues" ++> src.core.worksets { formatZodIssues }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/claude" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/claude" {
        frontmatter,
    }
    "src/core/shared/allowed-tools" ++> "src/core/command-generation/adapters/claude" {
        OPENSPEC_CLI_ALLOWED_TOOLS,
    }
    include "src/core/command-generation/adapters/amazon-q" ++> "src/core/command-generation/adapters/index" {
        amazonQAdapter,
    }
    include "src/core/command-generation/adapters/antigravity" ++> "src/core/command-generation/adapters/index" {
        antigravityAdapter,
    }
    include "src/core/command-generation/adapters/atomcode" ++> "src/core/command-generation/adapters/index" {
        atomcodeAdapter,
    }
    include "src/core/command-generation/adapters/auggie" ++> "src/core/command-generation/adapters/index" {
        auggieAdapter,
    }
    include "src/core/command-generation/adapters/bob" ++> "src/core/command-generation/adapters/index" {
        bobAdapter,
    }
    include "src/core/command-generation/adapters/claude" ++> "src/core/command-generation/adapters/index" {
        claudeAdapter,
    }
    include "src/core/command-generation/adapters/cline" ++> "src/core/command-generation/adapters/index" {
        clineAdapter,
    }
    include "src/core/command-generation/adapters/command-code" ++> "src/core/command-generation/adapters/index" {
        commandCodeAdapter,
    }
    include "src/core/command-generation/adapters/codebuddy" ++> "src/core/command-generation/adapters/index" {
        codebuddyAdapter,
    }
    include "src/core/command-generation/adapters/codestudio" ++> "src/core/command-generation/adapters/index" {
        codeStudioAdapter,
    }
    include "src/core/command-generation/adapters/continue" ++> "src/core/command-generation/adapters/index" {
        continueAdapter,
    }
    include "src/core/command-generation/adapters/costrict" ++> "src/core/command-generation/adapters/index" {
        costrictAdapter,
    }
    include "src/core/command-generation/adapters/crush" ++> "src/core/command-generation/adapters/index" {
        crushAdapter,
    }
    include "src/core/command-generation/adapters/cursor" ++> "src/core/command-generation/adapters/index" {
        cursorAdapter,
    }
    include "src/core/command-generation/adapters/devin" ++> "src/core/command-generation/adapters/index" {
        devinAdapter,
    }
    include "src/core/command-generation/adapters/easycode" ++> "src/core/command-generation/adapters/index" {
        easycodeAdapter,
    }
    include "src/core/command-generation/adapters/factory" ++> "src/core/command-generation/adapters/index" {
        factoryAdapter,
    }
    include "src/core/command-generation/adapters/gemini" ++> "src/core/command-generation/adapters/index" {
        geminiAdapter,
    }
    include "src/core/command-generation/adapters/github-copilot" ++> "src/core/command-generation/adapters/index" {
        githubCopilotAdapter,
    }
    include "src/core/command-generation/adapters/gigacode" ++> "src/core/command-generation/adapters/index" {
        gigacodeAdapter,
    }
    include "src/core/command-generation/adapters/iflow" ++> "src/core/command-generation/adapters/index" {
        iflowAdapter,
    }
    include "src/core/command-generation/adapters/junie" ++> "src/core/command-generation/adapters/index" {
        junieAdapter,
    }
    include "src/core/command-generation/adapters/kilocode" ++> "src/core/command-generation/adapters/index" {
        kilocodeAdapter,
    }
    include "src/core/command-generation/adapters/kiro" ++> "src/core/command-generation/adapters/index" {
        kiroAdapter,
    }
    include "src/core/command-generation/adapters/oh-my-pi" ++> "src/core/command-generation/adapters/index" {
        ohMyPiAdapter,
    }
    include "src/core/command-generation/adapters/opencode" ++> "src/core/command-generation/adapters/index" {
        opencodeAdapter,
    }
    include "src/core/command-generation/adapters/pi" ++> "src/core/command-generation/adapters/index" {
        piAdapter,
    }
    include "src/core/command-generation/adapters/codeassistant" ++> "src/core/command-generation/adapters/index" {
        codeassistantAdapter,
    }
    include "src/core/command-generation/adapters/qoder" ++> "src/core/command-generation/adapters/index" {
        qoderAdapter,
    }
    include "src/core/command-generation/adapters/lingma" ++> "src/core/command-generation/adapters/index" {
        lingmaAdapter,
    }
    include "src/core/command-generation/adapters/qwen" ++> "src/core/command-generation/adapters/index" {
        qwenAdapter,
    }
    include "src/core/command-generation/adapters/roocode" ++> "src/core/command-generation/adapters/index" {
        roocodeAdapter,
    }
    include "src/core/command-generation/adapters/trae" ++> "src/core/command-generation/adapters/index" {
        traeAdapter,
    }
    include "src/core/command-generation/adapters/zcode" ++> "src/core/command-generation/adapters/index" {
        zcodeAdapter,
    }
    src.host ++> "src/core/command-generation/registry" { rec }
    "src/core/command-generation/adapters/index" ++> "src/core/command-generation/registry" {
        amazonQAdapter,
        antigravityAdapter,
        atomcodeAdapter,
        auggieAdapter,
        bobAdapter,
        claudeAdapter,
        clineAdapter,
        commandCodeAdapter,
        devinAdapter,
        codebuddyAdapter,
        codeStudioAdapter,
        continueAdapter,
        costrictAdapter,
        crushAdapter,
        cursorAdapter,
        easycodeAdapter,
        factoryAdapter,
        geminiAdapter,
        githubCopilotAdapter,
        gigacodeAdapter,
        iflowAdapter,
        junieAdapter,
        kilocodeAdapter,
        kiroAdapter,
        ohMyPiAdapter,
        opencodeAdapter,
        piAdapter,
        codeassistantAdapter,
        qoderAdapter,
        lingmaAdapter,
        qwenAdapter,
        roocodeAdapter,
        traeAdapter,
        zcodeAdapter,
    }
    src.host ++> "src/utils/command-references" { sub }
    "src/core/command-generation/invocation" ++> "src/utils/command-references" {
        formatCommandInvocation,
    }
    src.host ++> "src/core/command-generation/generator" { merge, rec }
    "src/core/command-generation/invocation" ++> "src/core/command-generation/generator" {
        getInvocationForAdapter,
        needsInvocationRewrite,
    }
    "src/utils/command-references" ++> "src/core/command-generation/generator" {
        transformCommandInvocations,
    }
    include "src/core/command-generation/types" ++> "src/core/command-generation/index" {
        CommandContent,
        ToolCommandAdapter,
        GeneratedCommand,
    }
    include "src/core/command-generation/registry" ++> "src/core/command-generation/index" {
        CommandAdapterRegistry,
    }
    include "src/core/command-generation/generator" ++> "src/core/command-generation/index" {
        generateCommand,
        generateCommands,
    }
    include "src/core/command-generation/adapters/index" ++> "src/core/command-generation/index" {
        claudeAdapter,
        cursorAdapter,
        devinAdapter,
    }
    "src/core/command-generation/index" ++> "src/core/command-surface" { CommandAdapterRegistry }
    "src/core/command-generation/invocation" ++> "src/core/command-surface" {
        getInvocationForAdapter,
    }
    src.host ++> "src/ui/welcome-screen" { rec, merge, at, same, truthy }
    src.lazy ++> "src/ui/welcome-screen" { load, pick }
    "src/ui/ascii-patterns" ++> "src/ui/welcome-screen" { WELCOME_ANIMATION }
    "src/core/onboarding-commands" ++> "src/ui/welcome-screen" { getOnboardingCommands }
    src.host ++> src.telemetry.index { JsNull, rec, at, same, truthy, promise }
    "src/core/global-config" ++> src.telemetry.index { getGlobalConfig, isGlobalConfigUnreadable }
    src.utils.ci ++> src.telemetry.index { isCiEnvironment }
    src.telemetry.config ++> src.telemetry.index { getTelemetryConfig, updateTelemetryConfig }
    "src/telemetry/opt-out" ++> src.telemetry.index { isTelemetryOptedOutByEnv }
    src.host ++> "src/core/validation/purpose-placeholder" { JsNull, rec, sub, found }
    "src/core/parsers/code-fence" ++> "src/core/validation/purpose-placeholder" {
        buildCodeFenceMask,
    }
    src.core.validation.constants ++> "src/core/validation/purpose-placeholder" {
        PURPOSE_PLACEHOLDER_PREFIX,
        PURPOSE_PLACEHOLDER_SUFFIX,
    }
    src.host ++> "src/utils/spec-path-containment" { js_error }
    "src/core/project-dir" ++> "src/utils/spec-path-containment" { OPENSPEC_DIR_NAME }
    "src/utils/file-system" ++> "src/utils/spec-path-containment" { FileSystemUtils }
    src.host ++> "src/utils/spec-discovery" { rec, at, js_error }
    "src/utils/spec-path-containment" ++> "src/utils/spec-discovery" { assertDiscoveredSpecFile }
    "src/core/parsers/requirement-blocks" ++> "src/utils/spec-discovery" { parseDeltaSpec }
    src.host ++> "src/utils/item-discovery" { rec }
    "src/utils/spec-discovery" ++> "src/utils/item-discovery" { discoverSpecFiles }
    src.host ++> "src/prompts/searchable-multi-select" { JsNull, kind, merge, missing, rec, same }
    src.lazy ++> "src/prompts/searchable-multi-select" { load, pick }
    src.host ++> "src/core/schemas/base.schema" { rec }
    src.lazy ++> "src/core/schemas/base.schema" { need }
    src.core.validation.constants ++> "src/core/schemas/base.schema" { VALIDATION_MESSAGES }
    src.host ++> "src/core/schemas/spec.schema" { rec }
    src.lazy ++> "src/core/schemas/spec.schema" { need }
    "src/core/schemas/base.schema" ++> "src/core/schemas/spec.schema" { RequirementSchema }
    src.core.validation.constants ++> "src/core/schemas/spec.schema" { VALIDATION_MESSAGES }
    src.host ++> "src/core/schemas/change.schema" { rec }
    src.lazy ++> "src/core/schemas/change.schema" { need }
    "src/core/schemas/base.schema" ++> "src/core/schemas/change.schema" { RequirementSchema }
    src.core.validation.constants ++> "src/core/schemas/change.schema" {
        MAX_DELTAS_PER_CHANGE,
        MAX_WHY_SECTION_LENGTH,
        MIN_WHY_SECTION_LENGTH,
        VALIDATION_MESSAGES,
    }
    include "src/core/schemas/base.schema" ++> src.core.schemas.index {
        Requirement,
        RequirementSchema,
        Scenario,
        ScenarioSchema,
    }
    include "src/core/schemas/spec.schema" ++> src.core.schemas.index { Spec, SpecSchema }
    include "src/core/schemas/change.schema" ++> src.core.schemas.index {
        Change,
        ChangeSchema,
        Delta,
        DeltaOperation,
        DeltaOperationType,
        DeltaSchema,
    }
    src.host ++> src.core.validation.constants { rec }
    src.host ++> "src/ui/ascii-patterns" { rec }
    src.lazy ++> src.core.config { need }
    src.lazy ++> src.core.openers { need }
    src.lazy ++> "src/core/artifact-graph/types" { need }
    src.lazy ++> "src/core/artifact-graph/schema" { need }
    src.lazy ++> "src/core/change-metadata/schema" { need }
    "src/core/artifact-graph/schema" ++> "src/core/artifact-graph/graph" { loadSchema, parseSchema }
    src.host ++> src.core.openers { JsNull, at, found, merge, missing, rec }
    src.core.store.errors ++> src.core.openers { StoreError }
    "src/core/zod-issues" ++> src.core.openers { formatZodIssues }
    src.host ++> src.core.config { rec }
    include "src/core/project-dir" ++> src.core.config { OPENSPEC_DIR_NAME }
    src.host ++> "src/core/onboarding-commands" { JsNull, rec }
    src.core.profiles ++> "src/core/onboarding-commands" { ALL_WORKFLOWS }
    src.host ++> "src/core/shared/ide-restart" { JsNull }
    src.core.config ++> "src/core/shared/ide-restart" { AI_TOOLS }
    src.host ++> "src/core/shared/skill-paths" { at, missing, truthy }
    src.core.config ++> "src/core/shared/skill-paths" {
        AI_TOOLS,
        SKILL_LINKED_TOOL_IDS,
        installerAgent,
    }
    src.host ++> src.core.profiles { missing }
    src.host ++> "src/core/artifact-graph/types" { found, rec }
    src.host ++> "src/core/change-metadata/schema" { rec, rx }
    include src.core.id ++> "src/core/change-metadata/schema" { isKebabId }
    include "src/core/change-metadata/schema" ++> "src/core/change-metadata/index" {
        isKebabId,
        InitiativeLinkSchema,
        CHANGE_METADATA_KNOWN_KEYS,
        ChangeMetadataSchema,
        ChangeMetadata,
    }
    src.host ++> "src/core/artifact-graph/schema" { at, missing }
    "src/core/artifact-graph/types" ++> "src/core/artifact-graph/schema" { SchemaYamlSchema }
    src.lazy ++> "src/core/artifact-graph/outputs" { need }
    src.lazy ++> src.utils.interactive { load }
    src.host ++> "src/core/artifact-graph/outputs" { at, found, js_error, rec, sub }
    "src/utils/file-system" ++> "src/core/artifact-graph/outputs" { FileSystemUtils }
    "src/core/artifact-graph/outputs" ++> "src/core/artifact-graph/state" { artifactOutputExists }
    src.host ++> "src/core/file-state" { at, js_error, rec }
    src.core.store.errors ++> "src/core/file-state" { StoreError }
    "src/utils/file-system" ++> "src/core/file-state" { FileSystemUtils }
    src.host ++> "src/core/planning-home" { JsNull, at, rec }
    "src/utils/file-system" ++> "src/core/planning-home" { FileSystemUtils }
    src.host ++> "src/utils/file-system" { at, found, js_error, rec, sub }
    "src/utils/line-endings" ++> "src/utils/file-system" { detectLineEnding, matchLineEnding }
    src.host ++> src.utils.interactive { at, kind, owns, rec, truthy }
    src.host ++> "src/utils/shell-detection" { found, matchOf, rec, sub, truthy }
    "src/core/completions/shared-flags" ++> "src/core/completions/command-registry" { COMMON_FLAGS }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/amazon-q" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/amazon-q" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/antigravity" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/antigravity" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/auggie" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/auggie" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/bob" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/bob" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/codeassistant" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/codeassistant" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/codebuddy" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/codebuddy" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/codestudio" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/codestudio" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/costrict" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/costrict" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/crush" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/crush" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/cursor" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/cursor" {
        frontmatter,
        idField,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/devin" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/devin" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/factory" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/factory" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/gigacode" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/gigacode" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/github-copilot" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/github-copilot" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/iflow" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/iflow" {
        frontmatter,
        idField,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/junie" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/junie" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/kiro" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/kiro" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/lingma" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/lingma" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/qoder" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/qoder" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/qwen" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/qwen" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/trae" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/trae" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/zcode" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/zcode" {
        frontmatter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/cline" {
        commandAdapter,
        headedFile,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/roocode" {
        commandAdapter,
        headedFile,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/kilocode" {
        commandAdapter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/easycode" {
        commandAdapter,
    }
    "src/core/command-generation/toml" ++> "src/core/command-generation/adapters/easycode" {
        tomlCommandFile,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/gemini" {
        commandAdapter,
    }
    "src/core/command-generation/toml" ++> "src/core/command-generation/adapters/gemini" {
        tomlCommandFile,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/continue" {
        commandAdapter,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/continue" {
        frontmatter,
        idField,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/pi" {
        commandAdapter,
        provideArguments,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/pi" { frontmatter }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/oh-my-pi" {
        commandAdapter,
    }
    "src/core/command-generation/adapters/pi" ++> "src/core/command-generation/adapters/oh-my-pi" {
        piAdapter,
    }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/command-code" {
        commandAdapter,
        provideArguments,
    }
    src.host ++> "src/core/command-generation/adapters/command-code" { found }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/opencode" {
        commandAdapter,
        provideArguments,
    }
    "src/core/command-generation/yaml" ++> "src/core/command-generation/adapters/opencode" {
        frontmatter,
    }
    src.host ++> "src/core/command-generation/adapters/opencode" { found }
    "src/core/command-generation/types" ++> "src/core/command-generation/adapters/atomcode" {
        commandAdapter,
    }
    src.host ++> "src/core/command-generation/adapters/atomcode" { found, rec }
    src.lazy ++> "src/core/command-generation/adapters/atomcode" { need }
    src.host ++> "src/core/command-generation/yaml" { kind, sub }
    src.host ++> "src/core/command-generation/toml" { sub }
    src.host ++> "src/core/command-generation/types" { merge, rec, sub }
    src.host ++> "src/core/command-generation/invocation" { missing, rec }
    src.host ++> "src/core/completions/shared-flags" { rec }
    src.lazy ++> "src/core/config-schema" { need }
    src.host ++> "src/core/config-schema" { rec, missing, kind, js_error }
    src.host ++> "src/core/file-view" { rec }
    src.host ++> "src/core/global-config" {
        rec,
        merge,
        at,
        missing,
        kind,
        truthy,
        js_error,
        JsNull,
    }
    src.host ++> src.telemetry.config { rec, merge, at, missing, truthy, js_error }
    "src/core/global-config" ++> src.telemetry.config {
        GLOBAL_CONFIG_DIR_NAME,
        GLOBAL_CONFIG_FILE_NAME,
        getGlobalConfigDir,
        isConfigRootObject,
        unreadableGlobalConfigMessage,
    }
    src.lazy ++> "src/utils/requirement-diff" { need }
    src.host ++> "src/utils/requirement-diff" { JsNull, rec, missing }
    "src/core/parsers/requirement-blocks" ++> "src/utils/requirement-diff" {
        extractRequirementsSection,
        foldRequirementName,
        normalizeRequirementName,
    }
    src.host ++> "src/core/parsers/requirement-text" { rx, found, sub, rec }
    include "src/core/parsers/code-fence" ++> "src/core/parsers/requirement-text" {
        buildCodeFenceMask,
    }
    src.host ++> "src/core/parsers/requirement-blocks" {
        rx,
        sub,
        found,
        matchOf,
        rec,
        JsNull,
        missing,
    }
    "src/core/parsers/requirement-text" ++> "src/core/parsers/requirement-blocks" {
        buildCodeFenceMask,
        SCENARIO_HEADER,
    }
    src.host ++> "src/core/parsers/spec-structure" { sub, found, matchOf, rec }
    "src/core/parsers/code-fence" ++> "src/core/parsers/spec-structure" { buildCodeFenceMask }
    "src/core/parsers/requirement-blocks" ++> "src/core/parsers/spec-structure" {
        normalizeRequirementName,
        REQUIREMENTS_SECTION_HEADER_REGEX,
    }
    src.host ++> src.core.store.git { rec, merge, js_error, at, kind, same, JsNull, sub, matchOf }
    src.core.store.errors ++> src.core.store.git { StoreError }
    src.host ++> "src/core/parsers/code-fence" { matchOf }
    src.lazy ++> src.core.styles.palette { pick }
    src.host ++> src.core.styles.palette { rec }
    src.host ++> "src/core/change-status-policy" { rec, truthy }
    src.host ++> "src/commands/shared-output" { kind, merge, rec, truthy }
    src.core.store.errors ++> "src/commands/shared-output" { StoreError }
    src.host ++> src.commands.feedback { at, found, js_error, missing, rec, sub, truthy }
    src.host ++> src.core.templates.workflows.feedback { rec }
    src.host ++> src.core.templates.workflows.router { rec }
    src.host ++> src.core.store.errors { merge, rec }
    src.host ++> src.core.id { JsNull, rx, sub }
    "test/helpers/run-cli" --> "test/cli-e2e/apply-wrapped-tasks.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/archive-closed-requirement-heading.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/archive-requirement-name-near-miss.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/basic.test" { cliProjectRoot, runCLI, testBinary }
    "test/helpers/store-git" --> "test/cli-e2e/basic.test" { isolatedGitEnv }
    src.core.config --> "test/cli-e2e/basic.test" { AI_TOOLS }
    src.core.index --> "test/cli-e2e/basic.test" { getGlobalDataDir, registerStore }
    "test/helpers/openspec-fixtures" --> "test/cli-e2e/basic.test" { createOpenSpecRoot }
    src.core.index --> "test/helpers/store-git" { DEFAULT_OPENSPEC_SCHEMA }
    "src/core/global-config" --> src.core.index {
        GLOBAL_CONFIG_DIR_NAME,
        GLOBAL_CONFIG_FILE_NAME,
        GLOBAL_DATA_DIR_NAME,
        GlobalConfig,
        GlobalDataDirOptions,
        getGlobalConfig,
        getGlobalConfigDir,
        getGlobalConfigPath,
        getGlobalDataDir,
        saveGlobalConfig,
    }
    src.core.references --> src.core.index;
    src.core.store.index --> src.core.index;
    "src/core/planning-home" --> src.core.index;
    "src/core/openspec-root" --> src.core.index;
    src.core.store.errors --> src.core.references { StoreDiagnostic, makeStoreDiagnostic }
    src.core.store.foundation --> src.core.references {
        isValidStoreId,
        listStoreRegistryEntries,
        readStoreRegistryState,
    }
    src.core.store.registry --> src.core.references { getStoreRootForBackend }
    "src/core/root-selection" --> src.core.references {
        ResolvedOpenSpecRoot,
        inspectRegisteredStore,
    }
    "src/utils/item-discovery" --> src.core.references { getSpecIds }
    "src/utils/file-system" --> src.core.references { FileSystemUtils }
    "src/core/project-config" --> src.core.references { DeclarationEntry, MAX_CONTEXT_SIZE }
    src.core.store.foundation --> src.core.store.registry {
        StoreBackendConfig,
        StoreGitBackendConfig,
        StorePathOptions,
        StoreRegistryEntry,
        StoreRegistryState,
        getStoreMetadataDir,
        getStoreMetadataPath,
        listStoreRegistryEntries,
        readOptionalStoreMetadataState,
        readStoreRegistryState,
        resolveGitStoreBackendConfig,
        updateStoreRegistryState,
        validateStoreId,
        writeStoreMetadataState,
    }
    src.core.store.errors --> src.core.store.registry { StoreError }
    "src/utils/file-system" --> src.core.store.registry { FileSystemUtils }
    src.core.store.errors --> "src/core/root-selection" { StoreError }
    src.core.store.foundation --> "src/core/root-selection" {
        getStoreMetadataPath,
        listStoreRegistryEntries,
        readOptionalStoreMetadataState,
        readStoreRegistryState,
        validateStoreId,
    }
    src.core.store.registry --> "src/core/root-selection" { getStoreRootForBackend }
    src.core.store.git --> "src/core/root-selection" { gitOriginUrl, repoNameFromGitUrl }
    src.core.id --> "src/core/root-selection" { isKebabId, toKebabCase }
    "src/core/openspec-root" --> "src/core/root-selection" { inspectOpenSpecRoot }
    "src/core/planning-home" --> "src/core/root-selection" {
        PlanningHome,
        findRepoPlanningRootSync,
    }
    "src/core/project-config" --> "src/core/root-selection" {
        classifyOpenSpecDir,
        storePointerProblem,
    }
    "src/core/global-config" --> "src/core/root-selection" { getGlobalConfig }
    "src/utils/file-system" --> "src/core/root-selection" { FileSystemUtils }
    src.core.store.foundation --> src.core.store.index;
    src.core.store.errors --> src.core.store.index;
    src.core.store.registry --> src.core.store.index;
    src.core.store.operations --> src.core.store.index;
    "src/utils/file-system" --> src.core.store.operations { FileSystemUtils }
    "src/core/project-config" --> src.core.store.operations {
        classifyOpenSpecDir,
        storePointerProblem,
    }
    "src/core/openspec-root" --> src.core.store.operations {
        ANCHORED_OPENSPEC_DIRS,
        CreatedPathLedgerEntry,
        DIRECTORY_ANCHOR_FILE_NAME,
        OPENSPEC_ROOT_DIR,
        OpenSpecRootInspection,
        ensureOpenSpecRoot,
        inspectOpenSpecRoot,
        rollbackCreatedPaths,
    }
    src.core.store.foundation --> src.core.store.operations {
        STORE_METADATA_DIR_NAME,
        StoreGitBackendConfig,
        StorePathOptions,
        StoreRegistryState,
        getStoreMetadataDir,
        getStoreMetadataPath,
        getStoreRegistryPath,
        listStoreRegistryEntries,
        readOptionalStoreMetadataState,
        readStoreRegistryState,
        resolveGitStoreBackendConfig,
        validateStoreId,
        writeStoreMetadataState,
    }
    src.core.store.errors --> src.core.store.operations {
        StoreDiagnostic,
        StoreError,
        makeStoreDiagnostic,
    }
    src.core.store.git --> src.core.store.operations {
        GIT_EXEC_OPTIONS,
        assertGitCommitIdentity,
        commitStoreFiles,
        gitDirectoryHasTrackedFiles,
        gitHasCommits,
        gitHasRemote,
        gitHasUncommittedChanges,
        gitOriginUrl,
        initGitRepository,
        isGitRepositoryAtRoot,
    }
    src.core.store.registry --> src.core.store.operations {
        assertNoRegisteredStoreConflict,
        commitStoreRegistration,
        getRegisteredStore,
        getStoreRootForBackend,
        listRegisteredStores,
        unregisterStoreRegistration,
    }
    src.core.index --> "test/cli-e2e/capstone-journeys.test" { getGlobalDataDir, registerStore }
    "test/helpers/run-cli" --> "test/cli-e2e/capstone-journeys.test" { runCLI }
    "test/helpers/openspec-fixtures" --> "test/cli-e2e/capstone-journeys.test" {
        createOpenSpecRoot,
        writeSpec,
    }
    "test/helpers/temp-cleanup" --> "test/cli-e2e/capstone-journeys.test" { cleanupTempPath }
    "test/helpers/run-cli" --> "test/cli-e2e/completion-tip.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/spec-symlink-into-project.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/startup-modules.test" {
        cliProjectRoot,
        ensureCliBuilt,
    }
    "test/helpers/run-cli" --> "test/cli-e2e/store-lifecycle.test" { runCLI, testBinary }
    "test/helpers/temp-cleanup" --> "test/cli-e2e/store-lifecycle.test" { cleanupTempPath }
    "test/helpers/run-cli" --> "test/cli-e2e/unrecognized-delta-section.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/update-dry-run.test" { runCLI }
    "src/core/released-output-sweep" --> "test/cli-e2e/upgrade-from-releases.test" {
        currentGeneratablePaths,
        findStaleReleasedFiles,
    }
    src.core.migration --> "test/cli-e2e/upgrade-from-releases.test" { LEGACY_TOOL_ROOTS }
    src.core.config --> "src/core/released-output-sweep" {
        AI_TOOLS,
        SKILL_LINKED_TOOL_IDS,
        installerAgent,
    }
    "src/core/command-generation/index" --> "src/core/released-output-sweep" {
        CommandAdapterRegistry,
    }
    src.core.profiles --> "src/core/released-output-sweep" { SKILL_WORKFLOWS }
    "src/core/profile-sync-drift" --> "src/core/released-output-sweep" { WORKFLOW_TO_SKILL_DIR }
    "src/core/shared/tool-detection" --> "src/core/released-output-sweep" { COMMAND_IDS }
    "src/core/shared/generated-fingerprint" --> "src/core/released-output-sweep" {
        isReleasedGeneratedContent,
    }
    "src/core/shared/released-generated-fingerprints" --> "src/core/released-output-sweep" {
        RELEASED_GENERATED_PATHS,
    }
    src.core.migration --> "src/core/released-output-sweep" { LEGACY_TOOL_ROOTS, legacyCommandPath }
    "src/utils/file-system" --> "src/core/released-output-sweep" { FileSystemUtils }
    "src/core/file-view" --> "src/core/released-output-sweep" { DISK_VIEW, FileView }
    "src/core/shared-skill-target" --> "src/core/released-output-sweep" { isToolListed }
    "src/core/shared/skill-paths" --> "src/core/released-output-sweep" {
        SHARED_SKILLS_ROOT,
        usesSharedSkills,
    }
    "src/core/skill-installer" --> "src/core/released-output-sweep" { expectedSkillFiles }
    src.core.config --> "src/core/profile-sync-drift" { AI_TOOLS }
    "src/core/global-config" --> "src/core/profile-sync-drift" { Delivery }
    src.core.profiles --> "src/core/profile-sync-drift" { SKILL_WORKFLOWS, withRouter }
    "src/core/command-generation/index" --> "src/core/profile-sync-drift" { CommandAdapterRegistry }
    src.core.shared.index --> "src/core/profile-sync-drift" { getConfiguredTools }
    "src/core/shared/command-reconcile" --> "src/core/profile-sync-drift" { classifyCommandFiles }
    "src/core/command-surface" --> "src/core/profile-sync-drift" {
        shouldReconcileCommandFilesForTool,
    }
    "src/core/shared-skill-target" --> "src/core/profile-sync-drift" { isToolListed }
    "src/core/shared/shared-skill-install" --> "src/core/profile-sync-drift" {
        ownSkillFolderNeedsWork,
    }
    "src/utils/file-system" --> "src/core/profile-sync-drift" { FileSystemUtils }
    "src/core/file-view" --> "src/core/profile-sync-drift" { DISK_VIEW, FileView }
    "src/core/shared/skill-content-equivalence" --> "src/core/profile-sync-drift" {
        isRedundantLegacyCopy,
    }
    "src/core/shared/skill-paths" --> "src/core/profile-sync-drift" {
        resolveToolSkillsDir,
        toolSupportsSkills,
        usesSharedSkills,
    }
    "src/core/shared/tool-detection" --> src.core.shared.index {
        COMMAND_IDS,
        CommandId,
        SKILL_NAMES,
        SkillName,
        ToolSkillStatus,
        ToolVersionStatus,
        extractGeneratedByVersion,
        getAllToolVersionStatus,
        getConfiguredTools,
        getToolSkillStatus,
        getToolStates,
        getToolVersionStatus,
        getToolsWithSkillsDir,
        normalizeCommandContent,
    }
    "src/core/shared/skill-generation" --> src.core.shared.index {
        CommandTemplateEntry,
        SkillTemplateEntry,
        generateSkillContent,
        generateSkillFiles,
        getCommandContents,
        getCommandTemplates,
        getSkillTemplates,
    }
    "src/core/shared/skill-paths" --> src.core.shared.index {
        SkillCapableTool,
        getSkillCapableTools,
        hasGlobalSkillTarget,
        resolveToolSkillsDir,
        toolSupportsSkills,
    }
    "src/core/shared/ide-restart" --> src.core.shared.index {
        IdeRestartSurface,
        formatIdeRestart,
        resolveIdeRestartSurface,
    }
    src.core.config --> "src/core/shared/tool-detection" {
        AIToolOption,
        AI_TOOLS,
        OPENSPEC_SKILL_NAMES,
        agentsByProjectFolder,
        installerAgent,
    }
    "src/core/command-generation/index" --> "src/core/shared/tool-detection" {
        CommandAdapterRegistry,
    }
    "src/core/shared-skill-target" --> "src/core/shared/tool-detection" {
        hasLegacySkills,
        isToolListed,
        readListedToolsWithOwnFiles,
        readSkillToolList,
    }
    "src/core/command-surface" --> "src/core/shared/tool-detection" {
        resolveCommandSurfaceCapability,
    }
    "src/core/shared/skill-paths" --> "src/core/shared/tool-detection" {
        SkillCapableTool,
        getSkillCapableTools,
        resolveFormerOwnSkillsDir,
        resolveSharedSkillsDir,
        resolveSkillLinkDir,
        resolveToolSkillsDir,
        toolSupportsSkills,
        usesSharedSkills,
    }
    "src/core/file-view" --> "src/core/shared/tool-detection" { DISK_VIEW, FileView }
    "src/core/shared/skill-links" --> "src/core/shared/tool-detection" {
        classifySkillLinkSpot,
        isCheckedOutLink,
    }
    "src/core/shared/generated-fingerprint" --> "src/core/shared/tool-detection" {
        normalizeGeneratedContent,
    }
    "src/core/skill-installer" --> "src/core/shared/tool-detection" {
        expectedSkillContents,
        projectSkillText,
    }
    "src/utils/file-system" --> "src/core/shared/tool-detection" { FileSystemUtils }
    "src/utils/command-references" --> "src/core/skill-installer" {
        transformToSharedSkillReferences,
    }
    "src/core/shared/skill-generation" --> "src/core/skill-installer" {
        generateSkillFiles,
        getSkillTemplates,
        stripVolatileFrontmatter,
    }
    "src/core/templates/skill-templates" --> "src/core/shared/skill-generation" {
        ROUTER_SKILL_NAME,
        SkillTemplate,
        getApplyChangeSkillTemplate,
        getArchiveChangeSkillTemplate,
        getBulkArchiveChangeSkillTemplate,
        getContinueChangeSkillTemplate,
        getExploreSkillTemplate,
        getFfChangeSkillTemplate,
        getNewChangeSkillTemplate,
        getOnboardSkillTemplate,
        getOpsxApplyCommandTemplate,
        getOpsxArchiveCommandTemplate,
        getOpsxBulkArchiveCommandTemplate,
        getOpsxContinueCommandTemplate,
        getOpsxExploreCommandTemplate,
        getOpsxFfCommandTemplate,
        getOpsxNewCommandTemplate,
        getOpsxOnboardCommandTemplate,
        getOpsxProposeCommandTemplate,
        getOpsxProposeSkillTemplate,
        getOpsxSyncCommandTemplate,
        getOpsxUpdateCommandTemplate,
        getOpsxVerifyCommandTemplate,
        getRouterSkillTemplate,
        getSyncSpecsSkillTemplate,
        getUpdateChangeSkillTemplate,
        getVerifyChangeSkillTemplate,
    }
    "src/core/command-generation/index" --> "src/core/shared/skill-generation" { CommandContent }
    "src/core/shared/allowed-tools" --> "src/core/shared/skill-generation" {
        OPENSPEC_CLI_ALLOWED_TOOLS,
    }
    src.core.templates.types --> "src/core/templates/skill-templates" {
        CommandTemplate,
        SkillTemplate,
    }
    src.core.templates.workflows.explore --> "src/core/templates/skill-templates" {
        getExploreSkillTemplate,
        getOpsxExploreCommandTemplate,
    }
    "src/core/templates/workflows/new-change" --> "src/core/templates/skill-templates" {
        getNewChangeSkillTemplate,
        getOpsxNewCommandTemplate,
    }
    "src/core/templates/workflows/continue-change" --> "src/core/templates/skill-templates" {
        getContinueChangeSkillTemplate,
        getOpsxContinueCommandTemplate,
    }
    "src/core/templates/workflows/apply-change" --> "src/core/templates/skill-templates" {
        getApplyChangeSkillTemplate,
        getApplyInstructions,
        getOpsxApplyCommandTemplate,
    }
    "src/core/templates/workflows/update-change" --> "src/core/templates/skill-templates" {
        getOpsxUpdateCommandTemplate,
        getUpdateChangeSkillTemplate,
    }
    "src/core/templates/workflows/ff-change" --> "src/core/templates/skill-templates" {
        getFfChangeSkillTemplate,
        getOpsxFfCommandTemplate,
    }
    "src/core/templates/workflows/sync-specs" --> "src/core/templates/skill-templates" {
        getOpsxSyncCommandTemplate,
        getSyncSpecsSkillTemplate,
    }
    "src/core/templates/workflows/archive-change" --> "src/core/templates/skill-templates" {
        getArchiveChangeSkillTemplate,
        getOpsxArchiveCommandTemplate,
    }
    "src/core/templates/workflows/bulk-archive-change" --> "src/core/templates/skill-templates" {
        getBulkArchiveChangeSkillTemplate,
        getOpsxBulkArchiveCommandTemplate,
    }
    "src/core/templates/workflows/verify-change" --> "src/core/templates/skill-templates" {
        getOpsxVerifyCommandTemplate,
        getVerifyChangeSkillTemplate,
    }
    src.core.templates.workflows.onboard --> "src/core/templates/skill-templates" {
        getOnboardSkillTemplate,
        getOpsxOnboardCommandTemplate,
    }
    src.core.templates.workflows.propose --> "src/core/templates/skill-templates" {
        getOpsxProposeCommandTemplate,
        getOpsxProposeSkillTemplate,
    }
    src.core.templates.workflows.feedback --> "src/core/templates/skill-templates" {
        getFeedbackSkillTemplate,
    }
    src.core.templates.workflows.router --> "src/core/templates/skill-templates" {
        ROUTER_SKILL_NAME,
        getRouterSkillTemplate,
    }
    src.core.templates.types --> "src/core/templates/workflows/bulk-archive-change" {
        CommandTemplate,
        SkillTemplate,
    }
    "src/core/templates/workflows/archive-change" --> "src/core/templates/workflows/bulk-archive-change" {
        SYNC_FALLBACK_SAFEGUARDS,
    }
    "src/core/templates/workflows/store-selection" --> "src/core/templates/workflows/bulk-archive-change" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" --> "src/core/templates/workflows/bulk-archive-change" {
        PROJECT_ROOT_GUARD,
    }
    "src/utils/file-system" --> "src/core/shared/command-reconcile" { FileSystemUtils }
    "src/core/command-generation/index" --> "src/core/shared/command-reconcile" {
        CommandAdapterRegistry,
        generateCommands,
    }
    "src/core/command-generation/types" --> "src/core/shared/command-reconcile" { GeneratedCommand }
    src.core.config --> "src/core/shared/command-reconcile" { AI_TOOLS }
    src.core.migration --> "src/core/shared/command-reconcile" {
        LEGACY_TOOL_ROOTS,
        legacyCommandPath,
    }
    src.core.profiles --> "src/core/shared/command-reconcile" { ALL_WORKFLOWS }
    "src/core/shared/skill-generation" --> "src/core/shared/command-reconcile" {
        getCommandContents,
    }
    "src/core/shared/tool-detection" --> "src/core/shared/command-reconcile" {
        normalizeCommandContent,
    }
    "src/core/shared/generated-fingerprint" --> "src/core/shared/command-reconcile" {
        isReleasedGeneratedContent,
    }
    "src/core/file-view" --> "src/core/shared/command-reconcile" { DISK_VIEW, FileView }
    src.core.config --> src.core.migration { AIToolOption, AI_TOOLS }
    "src/core/global-config" --> src.core.migration {
        GlobalConfig,
        Profile,
        getGlobalConfig,
        getGlobalConfigPath,
        isGlobalConfigUnreadable,
        saveGlobalConfig,
    }
    "src/core/command-generation/index" --> src.core.migration { CommandAdapterRegistry }
    "src/core/profile-sync-drift" --> src.core.migration { WORKFLOW_TO_SKILL_DIR }
    "src/core/shared/tool-detection" --> src.core.migration { COMMAND_IDS }
    src.core.profiles --> src.core.migration { ALL_WORKFLOWS, CORE_WORKFLOWS, SKILL_WORKFLOWS }
    "src/utils/command-references" --> src.core.migration { getSkillReferenceTransformer }
    "src/utils/file-system" --> src.core.migration { FileSystemUtils }
    "src/core/shared-skill-target" --> src.core.migration { isToolListed }
    "src/core/file-view" --> src.core.migration { DISK_VIEW, FileView }
    "src/core/shared/skill-content-equivalence" --> src.core.migration { isRedundantLegacyCopy }
    "src/core/shared/skill-paths" --> src.core.migration {
        resolveFormerOwnSkillsDir,
        resolveToolSkillsDir,
        toolSupportsSkills,
        usesSharedSkills,
    }
    src.core.config --> "src/core/shared/shared-skill-install" {
        AIToolOption,
        OPENSPEC_SKILL_NAMES,
        installerAgent,
    }
    "src/utils/file-system" --> "src/core/shared/shared-skill-install" { FileSystemUtils }
    "src/core/shared/generated-fingerprint" --> "src/core/shared/shared-skill-install" {
        normalizeGeneratedFile,
    }
    "src/core/file-view" --> "src/core/shared/shared-skill-install" { FileView }
    "src/core/update-plan" --> "src/core/shared/shared-skill-install" { UpdateFileOps }
    "src/core/released-output-sweep" --> "src/core/shared/shared-skill-install" {
        pruneEmptyParents,
    }
    "src/core/shared-skill-target" --> "src/core/shared/shared-skill-install" {
        formatSkillToolList,
        readListedToolsWithOwnFiles,
        skillToolListPath,
    }
    "src/core/skill-installer" --> "src/core/shared/shared-skill-install" {
        expectedSkillFiles,
        installReleaseSkills,
        projectSkillText,
        removeManagedSkills,
    }
    "src/core/shared/skill-paths" --> "src/core/shared/shared-skill-install" {
        resolveFormerOwnSkillsDir,
        resolveSharedSkillsDir,
        resolveSkillLinkDir,
        usesSharedSkills,
    }
    "src/utils/file-system" --> "src/core/update-plan" { FileSystemUtils }
    "src/core/file-view" --> "src/core/update-plan" { DISK_VIEW, FileView }
    "src/core/shared/skill-links" --> "src/core/update-plan" { createSkillLink, skillLinkText }
    "test/helpers/run-cli" --> "test/cli-e2e/validate-archived-tasks.test" { runCLI }
    src.core.index --> "test/cli-e2e/validate-findings.test" { getGlobalDataDir, registerStore }
    "test/helpers/run-cli" --> "test/cli-e2e/validate-findings.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/validate-international.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/validate-scenario-loss.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/validate-task-checkboxes.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/validate-task-numbering.test" { runCLI }
    "test/helpers/run-cli" --> "test/cli-e2e/view-store-resolution.test" { runCLI }
    "test/helpers/temp-cleanup" --> "test/cli-e2e/view-store-resolution.test" { cleanupTempPath }
    src.core.index --> "test/cli-e2e/workset-journey.test" { getGlobalDataDir, registerStore }
    src.core.worksets --> "test/cli-e2e/workset-journey.test" { getWorksetsDir }
    "test/helpers/run-cli" --> "test/cli-e2e/workset-journey.test" { RunCLIResult, runCLI }
    "test/helpers/openspec-fixtures" --> "test/cli-e2e/workset-journey.test" { createOpenSpecRoot }
    "test/helpers/fake-tool" --> "test/cli-e2e/workset-journey.test" {
        createFakeTool,
        envWithFakeTools,
        readLaunchLog,
    }
    "test/helpers/fs-snapshot" --> "test/cli-e2e/workset-journey.test" { snapshotDirectory }
    "test/helpers/path-env" --> "test/helpers/fake-tool" { withPrependedPathEnv }
    src.commands.workflow.instructions --> "test/commands/apply-instructions-blocked.test" {
        generateApplyInstructions,
        printApplyInstructionsText,
    }
    "src/core/artifact-graph/index" --> src.commands.workflow.instructions {
        ArtifactInstructions,
        generateInstructions,
        loadChangeContext,
        resolveArtifactOutputs,
        resolveSchema,
    }
    "src/core/artifact-graph/outputs" --> src.commands.workflow.instructions { isSpecsArtifactPath }
    "src/utils/spec-discovery" --> src.commands.workflow.instructions { findUnreadDeltaFiles }
    "src/core/planning-home" --> src.commands.workflow.instructions {
        PlanningHome,
        getChangeDir,
        resolveCurrentPlanningHomeSync,
    }
    "src/core/root-selection" --> src.commands.workflow.instructions {
        ResolvedOpenSpecRoot,
        resolveRootForCommand,
        toPlanningHome,
        toRootOutput,
        withStoreFlag,
    }
    src.core.references --> src.commands.workflow.instructions {
        ReferenceIndexEntry,
        assembleReferenceIndex,
        escapeEnvelopeAttribute,
        escapeEnvelopeTags,
        renderReferencedStoresBlock,
        renderReferencedStoresSection,
        sanitizeInline,
    }
    src.core.store.registry --> src.commands.workflow.instructions { readRegistrySnapshot }
    "src/core/project-config" --> src.commands.workflow.instructions {
        ProjectConfig,
        loadOperationInputs,
        readProjectConfig,
    }
    src.commands.workflow.shared --> src.commands.workflow.instructions {
        ApplyInstructions,
        ArchiveInstructions,
        TaskItem,
        validateChangeExists,
        validateSchemaExists,
    }
    "src/utils/task-progress" --> src.commands.workflow.instructions {
        ParsedTask,
        parseLocatedTaskLines,
    }
    "src/utils/change-metadata" --> src.commands.workflow.instructions { METADATA_FILENAME }
    "src/core/artifact-graph/types" --> "src/core/artifact-graph/index" {
        Artifact,
        ArtifactSchema,
        BlockedArtifacts,
        CompletedSet,
        SchemaYaml,
        SchemaYamlSchema,
    }
    "src/core/artifact-graph/schema" --> "src/core/artifact-graph/index" {
        SchemaValidationError,
        loadSchema,
        parseSchema,
    }
    "src/core/artifact-graph/graph" --> "src/core/artifact-graph/index" { ArtifactGraph }
    "src/core/artifact-graph/state" --> "src/core/artifact-graph/index" { detectCompleted }
    "src/core/artifact-graph/outputs" --> "src/core/artifact-graph/index" {
        artifactOutputExists,
        isGlobPattern,
        resolveArtifactOutputPath,
        resolveArtifactOutputs,
    }
    "src/core/artifact-graph/resolver" --> "src/core/artifact-graph/index" {
        SchemaInfo,
        SchemaLoadError,
        getPackageSchemasDir,
        getSchemaDir,
        getUserSchemasDir,
        listSchemas,
        listSchemasWithInfo,
        resolveSchema,
    }
    "src/core/artifact-graph/instruction-loader" --> "src/core/artifact-graph/index" {
        ArtifactInstructions,
        ArtifactPathSummary,
        ArtifactStatus,
        ChangeContext,
        ChangeStatus,
        DependencyInfo,
        LoadChangeContextOptions,
        TemplateLoadError,
        formatChangeStatus,
        generateInstructions,
        loadChangeContext,
        loadTemplate,
    }
    "src/core/change-status-policy" --> "src/core/artifact-graph/index" {
        ActionContext,
        PlanningHomeSummary,
    }
    "src/core/artifact-graph/resolver" --> "src/core/artifact-graph/instruction-loader" {
        getSchemaDir,
        listSchemasWithInfo,
        resolveSchema,
    }
    "src/core/artifact-graph/graph" --> "src/core/artifact-graph/instruction-loader" {
        ArtifactGraph,
    }
    "src/core/artifact-graph/state" --> "src/core/artifact-graph/instruction-loader" {
        detectCompleted,
    }
    "src/core/artifact-graph/outputs" --> "src/core/artifact-graph/instruction-loader" {
        isSpecsArtifactPath,
        resolveArtifactOutputPath,
        resolveArtifactOutputs,
    }
    "src/utils/change-metadata" --> "src/core/artifact-graph/instruction-loader" {
        formatUnknownChangeMetadataKeysMessage,
        readChangeMetadata,
        readUnknownChangeMetadataKeys,
        resolveSchemaForChange,
    }
    "src/utils/file-system" --> "src/core/artifact-graph/instruction-loader" { FileSystemUtils }
    "src/core/change-status-policy" --> "src/core/artifact-graph/instruction-loader" {
        ActionContext,
        PlanningHomeSummary,
        buildActionContext,
        buildNextSteps,
        summarizePlanningHome,
    }
    "src/core/project-config" --> "src/core/artifact-graph/instruction-loader" {
        ProjectConfig,
        readProjectConfig,
        validateConfigRules,
    }
    src.core.references --> "src/core/artifact-graph/instruction-loader" { ReferenceIndexEntry }
    "src/core/planning-home" --> "src/core/artifact-graph/instruction-loader" { PlanningHome }
    "src/core/change-metadata/index" --> "src/core/artifact-graph/instruction-loader" {
        ChangeMetadata,
    }
    "src/core/artifact-graph/types" --> "src/core/artifact-graph/instruction-loader" {
        Artifact,
        CompletedSet,
    }
    "src/core/change-metadata/index" --> "src/utils/change-metadata" {
        CHANGE_METADATA_KNOWN_KEYS,
        ChangeMetadata,
        ChangeMetadataSchema,
    }
    "src/core/artifact-graph/resolver" --> "src/utils/change-metadata" {
        listSchemas,
        resolveSchema,
    }
    "src/core/project-config" --> "src/utils/change-metadata" { ProjectConfig, readProjectConfig }
    src.core.references --> "src/utils/change-metadata" { sanitizeInline }
    "src/utils/nested-change" --> src.commands.workflow.shared {
        describeNestedChange,
        findNestedChangesIn,
    }
    "src/core/artifact-graph/index" --> src.commands.workflow.shared { getSchemaDir, listSchemas }
    src.core.references --> src.commands.workflow.shared { ReferenceIndexEntry }
    "src/core/root-selection" --> src.commands.workflow.shared { isRootSelectionError }
    "src/commands/workflow/default-schema" --> src.commands.workflow.shared { DEFAULT_SCHEMA }
    "src/core/artifact-graph/outputs" --> "src/utils/nested-change" { artifactOutputExists }
    "src/core/artifact-graph/resolver" --> "src/utils/nested-change" { resolveSchema }
    "src/utils/change-metadata" --> "src/utils/nested-change" {
        METADATA_FILENAME,
        resolveSchemaForChange,
    }
    "src/utils/spec-discovery" --> "src/utils/nested-change" { hasAnyFileUnder }
    "src/core/artifact-graph/index" --> "src/utils/task-progress" {
        Artifact,
        SchemaYaml,
        resolveArtifactOutputs,
        resolveSchema,
    }
    "src/utils/change-metadata" --> "src/utils/task-progress" { resolveSchemaForChange }
    src.commands.workflow.instructions --> "test/commands/apply-instructions-tasks.test" {
        generateApplyInstructions,
    }
    "src/utils/task-progress" --> "test/commands/apply-instructions-tasks.test" {
        getTaskProgressForChange,
    }
    src.commands.workflow.instructions --> "test/commands/apply-instructions-warnings.test" {
        generateApplyInstructions,
        printApplyInstructionsText,
    }
    src.core.validation.validator --> "test/commands/apply-instructions-warnings.test" { Validator }
    src.core.schemas.index --> src.core.validation.validator {
        Change,
        ChangeSchema,
        Spec,
        SpecSchema,
    }
    "src/core/parsers/markdown-parser" --> src.core.validation.validator { MarkdownParser }
    "src/core/parsers/change-parser" --> src.core.validation.validator { ChangeParser }
    src.core.validation.types --> src.core.validation.validator {
        ValidationIssue,
        ValidationLevel,
        ValidationReport,
    }
    "src/core/specs-apply" --> src.core.validation.validator { buildUpdatedSpec, findSpecUpdates }
    src.core.validation.constants --> src.core.validation.validator {
        MAX_REQUIREMENT_TEXT_LENGTH,
        MIN_PURPOSE_LENGTH,
        VALIDATION_MESSAGES,
    }
    "src/core/parsers/requirement-blocks" --> src.core.validation.validator {
        RequirementBlock,
        describeScenarioBalance,
        describeUnappliedContent,
        diffScenarioNames,
        extractRequirementsSection,
        foldRequirementName,
        isScenarioLabeledHeader,
        isUnrecognizedDeltaSection,
        normalizeRequirementName,
        parseDeltaSpec,
        parseScenarioBlocks,
    }
    "src/core/parsers/requirement-text" --> src.core.validation.validator {
        containsShallOrMust,
        countEmptyScenarios,
        countScenarios,
        extractRequirementBody,
        hasScenarioBody,
        scenarioStepCoverage,
    }
    "src/core/parsers/spec-structure" --> src.core.validation.validator {
        findMainSpecStructureIssues,
    }
    "src/utils/file-system" --> src.core.validation.validator { FileSystemUtils }
    "src/utils/spec-path-containment" --> src.core.validation.validator { assertDiscoveredSpecFile }
    "src/utils/spec-discovery" --> src.core.validation.validator {
        discoverSpecFiles,
        findUnreadDeltaFiles,
        hasAnyFileUnder,
    }
    "src/utils/change-metadata" --> src.core.validation.validator {
        METADATA_FILENAME,
        formatUnknownChangeMetadataKeysMessage,
        readSkipSpecsMarker,
        readUnknownChangeMetadataKeys,
        resolveSchemaForChange,
    }
    "src/utils/task-progress" --> src.core.validation.validator { resolveTaskFilesForChange }
    "src/core/validation/task-numbering" --> src.core.validation.validator {
        findTaskNumberingIssues,
    }
    "src/core/validation/task-checkboxes" --> src.core.validation.validator {
        findMissingTaskCheckboxIssues,
    }
    "src/core/validation/purpose-placeholder" --> src.core.validation.validator {
        findPurposePlaceholderIssue,
    }
    "src/core/artifact-graph/index" --> src.core.validation.validator {
        getPackageSchemasDir,
        getSchemaDir,
    }
    "src/core/parsers/requirement-blocks" --> "src/core/specs-apply" {
        RequirementBlock,
        RequirementsSectionParts,
        describeScenarioBalance,
        describeUnappliedContent,
        diffScenarioNames,
        extractRequirementsSection,
        findFrontmatterEnd,
        foldRequirementName,
        isUnrecognizedDeltaSection,
        normalizeRequirementName,
        parseDeltaSpec,
    }
    "src/core/parsers/spec-structure" --> "src/core/specs-apply" { findMainSpecStructureIssues }
    "src/core/parsers/code-fence" --> "src/core/specs-apply" { buildCodeFenceMask }
    "src/core/parsers/markdown-parser" --> "src/core/specs-apply" { MarkdownParser }
    src.core.validation.constants --> "src/core/specs-apply" {
        MIN_PURPOSE_LENGTH,
        PURPOSE_PLACEHOLDER_PREFIX,
        PURPOSE_PLACEHOLDER_SUFFIX,
    }
    "src/utils/spec-discovery" --> "src/core/specs-apply" { discoverSpecFiles }
    "src/utils/file-system" --> "src/core/specs-apply" { FileSystemUtils }
    "src/utils/spec-path-containment" --> "src/core/specs-apply" { assertSpecFileWithin }
    "src/utils/line-endings" --> "src/core/specs-apply" { matchLineEnding }
    "src/utils/task-progress" --> "src/core/validation/task-numbering" { parseTaskLines }
    "src/utils/task-progress" --> "src/core/validation/task-checkboxes" { parseTaskLines }
    "test/helpers/run-cli" --> "test/commands/artifact-workflow.test" { runCLI }
    "src/utils/file-system" --> "test/commands/artifact-workflow.test" { FileSystemUtils }
    "src/utils/change-metadata" --> "test/commands/change-initiative-link.test" {
        readChangeMetadata,
    }
    "test/helpers/run-cli" --> "test/commands/change-initiative-link.test" { RunCLIResult, runCLI }
    src.commands.completion --> "test/commands/completion.test" { CompletionCommand }
    "src/utils/shell-detection" --> "test/commands/completion.test";
    "src/core/completions/installers/zsh-installer" --> "test/commands/completion.test";
    src.core.completions.factory --> src.commands.completion { CompletionFactory }
    "src/core/completions/installers/zsh-installer" --> src.commands.completion { zshrcDisplayPath }
    "src/core/completions/command-registry" --> src.commands.completion { COMMAND_REGISTRY }
    "src/utils/shell-detection" --> src.commands.completion { SupportedShell, detectShell }
    "src/core/completions/completion-provider" --> src.commands.completion { CompletionProvider }
    "src/utils/item-discovery" --> src.commands.completion { getArchivedChangeIds }
    "src/utils/item-discovery" --> "src/core/completions/completion-provider" {
        getActiveChangeIds,
        getSpecIds,
    }
    "src/core/artifact-graph/resolver" --> "src/core/completions/completion-provider";
    "test/helpers/run-cli" --> "test/commands/config-edit.test" { runCLI }
    src.cli.commands.config --> "test/commands/config-edit.test";
    src.commands.config --> "test/commands/config-edit.test";
    src.commands.config --> src.cli.commands.config;
    "src/core/global-config" --> src.commands.config {
        Delivery,
        GlobalConfig,
        Profile,
        getGlobalConfig,
        getGlobalConfigPath,
        isConfigRootObject,
        isGlobalConfigUnreadable,
        saveGlobalConfig,
    }
    "src/core/config-schema" --> src.commands.config {
        DEFAULT_CONFIG,
        coerceValue,
        deleteNestedValue,
        formatValueYaml,
        getNestedValue,
        hasUnsafeKeySegment,
        setNestedValue,
        validateConfig,
        validateConfigKeyPath,
    }
    src.core.profiles --> src.commands.config { ALL_WORKFLOWS, CORE_WORKFLOWS, getProfileWorkflows }
    src.core.config --> src.commands.config { OPENSPEC_DIR_NAME }
    "src/commands/shared-output" --> src.commands.config {
        asErrorMessage,
        isPromptCancellationError,
    }
    "src/core/profile-sync-drift" --> src.commands.config;
    src.core.update --> src.commands.config;
    "src/utils/file-system" --> src.core.update { FileSystemUtils }
    "src/utils/command-references" --> src.core.update {
        getSkillReferenceTransformer,
        transformToSkillReferences,
    }
    src.core.config --> src.core.update { AI_TOOLS, OPENSPEC_DIR_NAME }
    src.core.shared.index --> src.core.update {
        ToolVersionStatus,
        formatIdeRestart,
        getToolSkillStatus,
        getToolVersionStatus,
        getToolsWithSkillsDir,
        resolveToolSkillsDir,
        toolSupportsSkills,
    }
    "src/core/shared/command-reconcile" --> src.core.update {
        formatKeptCommandFiles,
        reconcileCommandFiles,
    }
    "src/core/project-skills-scope" --> src.core.update {
        keepsProjectSkills,
        rememberProjectSkills,
    }
    "src/core/skill-installer" --> src.core.update { expectedSkillFiles, projectSkillText }
    "src/core/legacy-cleanup" --> src.core.update {
        LegacyCleanupOps,
        LegacyDetectionResult,
        cleanupLegacyArtifacts,
        detectLegacyArtifacts,
        findEditedLegacyGlobalPrompts,
        formatCleanupSummary,
        formatDeferredGlobalPromptSummary,
        formatDetectionSummary,
        getLegacyGlobalPromptMatches,
        getLegacyWorkflowIdsForTool,
        getToolsFromLegacyArtifacts,
        hasRepoLocalLegacyRemovals,
        legacyCleanupDeletesOnlyReleasedOutput,
        omitGlobalLegacyPromptFiles,
        omitToolLegacyArtifacts,
        pickGlobalLegacyPromptFiles,
    }
    src.utils.interactive --> src.core.update { isInteractive }
    "src/core/released-output-sweep" --> src.core.update {
        findStaleReleasedFiles,
        pruneEmptyParents,
    }
    "src/core/retired-tools" --> src.core.update { cleanUpRetiredTools, formatRetiredToolCleanup }
    "src/core/global-config" --> src.core.update {
        Delivery,
        Profile,
        getGlobalConfig,
        getGlobalConfigPath,
        serializeGlobalConfig,
    }
    src.core.profiles --> src.core.update {
        CORE_WORKFLOWS,
        SKILL_WORKFLOWS,
        getProfileWorkflows,
        withRouter,
    }
    "src/core/onboarding-commands" --> src.core.update {
        formatOptionalWorkflowsNote,
        getOnboardingCommands,
    }
    "src/core/available-tools" --> src.core.update { getAvailableTools }
    "src/core/profile-sync-drift" --> src.core.update {
        getConfiguredToolsForProfileSync,
        getToolsNeedingProfileSync,
    }
    src.core.migration --> src.core.update {
        LEGACY_TOOL_ROOTS,
        LegacyToolMigration,
        applyProfileMigration,
        computeProfileMigration,
        describeLegacyMigration,
        findLegacyToolMigrations,
        hasMovableContent,
        keptInPlaceNotice,
        legacyMigrationNotice,
        migrateIfNeeded,
        migrateLegacyToolDirs,
        planLegacyToolMigrations,
        scanInstalledWorkflows,
    }
    "src/core/command-surface" --> src.core.update { shouldReconcileCommandFilesForTool }
    "src/core/shared/generated-fingerprint" --> src.core.update { normalizeGeneratedFile }
    "src/core/shared/skill-paths" --> src.core.update { resolveSkillLinkDir, usesSharedSkills }
    "src/core/shared-skill-target" --> src.core.update { isToolListed }
    "src/core/shared/shared-skill-install" --> src.core.update {
        SharedSkillInstallResult,
        installSharedSkills,
    }
    "src/core/file-view" --> src.core.update { DISK_VIEW, FileView }
    "src/core/known-projects" --> src.core.update { rememberProject }
    "src/core/update-plan" --> src.core.update {
        UpdateFileOps,
        UpdatePlan,
        UpdatePlanRecorder,
        realFileOps,
    }
    "src/core/github-copilot/cloud-agent" --> src.core.update {
        CopilotCloudFileOps,
        findUnmanagedCloudFiles,
        includesGitHubCopilot,
        isCopilotCloudEnabled,
        readCopilotCloudOptIn,
        removeCopilotCloudFiles,
        writeCopilotCloudFiles,
    }
    "src/core/global-skills" --> src.core.update;
    src.core.init --> src.core.update;
    "src/prompts/searchable-multi-select" --> src.core.update;
    src.core.config --> "src/core/retired-tools" {
        OPENSPEC_SKILL_NAMES,
        RETIRED_TOOLS,
        RetiredTool,
        findRetiredTool,
        formatRetiredToolError,
    }
    "src/core/shared/command-reconcile" --> "src/core/retired-tools" { reconcileCommandFiles }
    "src/core/shared/skill-links" --> "src/core/retired-tools" { classifySkillFile }
    "src/core/legacy-cleanup" --> "src/core/retired-tools" { reachesWithoutLink }
    "src/core/released-output-sweep" --> "src/core/retired-tools" { pruneEmptyParents }
    src.core.profiles --> "src/core/retired-tools" { ALL_WORKFLOWS }
    "src/core/file-view" --> "src/core/retired-tools" { FileView }
    src.core.config --> "src/core/available-tools" { AIToolOption, AI_TOOLS }
    "src/core/shared-skill-target" --> "src/core/available-tools" { readSkillToolList }
    "src/core/shared/tool-detection" --> "src/core/available-tools" {
        SKILL_NAMES,
        isListedToolPresent,
    }
    "src/core/shared/skill-paths" --> "src/core/available-tools" {
        SHARED_SKILLS_ROOT,
        resolveToolSkillsDir,
        toolSupportsSkills,
        usesSharedSkills,
    }
    "src/core/file-view" --> "src/core/available-tools" { DISK_VIEW, FileView }
    "src/utils/file-system" --> "src/core/github-copilot/cloud-agent" { FileSystemUtils }
    "src/core/project-config" --> "src/core/github-copilot/cloud-agent" {
        readProjectConfig,
        resolveConfigFilePath,
    }
    src.core.config --> "src/core/global-skills" { AI_TOOLS, OPENSPEC_SKILL_NAMES, installerAgent }
    "src/core/global-config" --> "src/core/global-skills" { getGlobalDataDir }
    src.core.profiles --> "src/core/global-skills" { withRouter }
    "src/core/shared/tool-detection" --> "src/core/global-skills" { getConfiguredTools }
    "src/core/skill-installer" --> "src/core/global-skills" {
        SkillScope,
        expectedSkillFiles,
        installReleaseSkills,
        removeManagedSkills,
    }
    "src/utils/file-system" --> src.core.init { FileSystemUtils }
    "src/core/project-skills-scope" --> src.core.init { forgetProjectSkills }
    "src/core/project-config" --> src.core.init {
        MAX_CONTEXT_SIZE,
        classifyOpenSpecDir,
        readProjectConfig,
        storePointerProblem,
    }
    "src/core/planning-home" --> src.core.init { findRepoPlanningRootSync }
    "src/core/root-selection" --> src.core.init { resolveOpenSpecRoot }
    "src/core/openspec-root" --> src.core.init { ANCHORED_OPENSPEC_DIRS, ensureDirectoryAnchor }
    "src/utils/command-references" --> src.core.init {
        getSkillReferenceTransformer,
        transformToSkillReferences,
        usesNaturalLanguageSkillReferences,
    }
    src.core.config --> src.core.init {
        AIToolOption,
        AI_TOOLS,
        OPENSPEC_DIR_NAME,
        SKILL_LINKED_TOOL_IDS,
        getUniversalTool,
        installerAgent,
        resolveToolIdAlias,
        universalToolFallbackHint,
    }
    src.core.styles.palette --> src.core.init { PALETTE }
    src.utils.interactive --> src.core.init { isInteractive }
    "src/core/config-prompts" --> src.core.init { serializeConfig }
    "src/core/legacy-cleanup" --> src.core.init {
        LegacyDetectionResult,
        cleanupLegacyArtifacts,
        detectLegacyArtifacts,
        formatCleanupSummary,
        formatDeferredGlobalPromptSummary,
        formatDetectionSummary,
        getLegacyGlobalPromptMatches,
        omitGlobalLegacyPromptFiles,
        pickGlobalLegacyPromptFiles,
    }
    src.core.shared.index --> src.core.init {
        ToolSkillStatus,
        formatIdeRestart,
        getConfiguredTools,
        getSkillTemplates,
        getToolStates,
        getToolsWithSkillsDir,
        toolSupportsSkills,
    }
    "src/core/shared/command-reconcile" --> src.core.init {
        classifyCommandFiles,
        formatKeptCommandFiles,
        reconcileCommandFiles,
    }
    "src/core/retired-tools" --> src.core.init {
        cleanUpRetiredTools,
        findRetiredTool,
        formatRetiredToolCleanup,
        formatRetiredToolError,
    }
    "src/core/released-output-sweep" --> src.core.init { pruneEmptyParents }
    "src/core/global-config" --> src.core.init { Delivery, Profile, getGlobalConfig }
    "src/core/global-skills" --> src.core.init {
        SKILL_SCOPES,
        SkillScope,
        describeRemovedSkills,
        describeSkillsError,
        installGlobalSkills,
        isHomeFolder,
        projectHasOwnSkills,
        readGlobalSkills,
        supportsGlobalSkills,
    }
    src.core.profiles --> src.core.init { getProfileWorkflows, withRouter }
    "src/core/available-tools" --> src.core.init { getAvailableTools }
    "src/core/onboarding-commands" --> src.core.init { formatOptionalWorkflowsNote }
    "src/core/shared/skill-paths" --> src.core.init { usesSharedSkills }
    "src/core/shared/shared-skill-install" --> src.core.init { installSharedSkills }
    "src/core/update-plan" --> src.core.init { UpdatePlanRecorder, realFileOps }
    "src/core/file-view" --> src.core.init { DISK_VIEW }
    "src/core/known-projects" --> src.core.init { rememberProject }
    src.core.migration --> src.core.init {
        computeProfileMigration,
        describeLegacyMigration,
        hasMovableContent,
        keptInPlaceNotice,
        migrateIfNeeded,
        migrateLegacyToolDirs,
        scanInstalledWorkflows,
    }
    "src/core/command-surface" --> src.core.init { shouldReconcileCommandFilesForTool }
    "src/core/github-copilot/cloud-agent" --> src.core.init {
        findUnmanagedCloudFiles,
        hasExistingManagedCloudFiles,
        listManagedCloudFiles,
        persistCopilotCloudOptIn,
        readCopilotCloudOptIn,
        removeCopilotCloudFiles,
        writeCopilotCloudFiles,
    }
    "src/ui/welcome-screen" --> src.core.init;
    "src/prompts/searchable-multi-select" --> src.core.init;
    src.cli.commands.config --> "test/commands/config-profile.test";
    src.commands.config --> "test/commands/config-profile.test";
    "src/core/global-config" --> "test/commands/config-profile.test";
    src.core.profiles --> "test/commands/config-profile.test";
    src.core.update --> "test/commands/config-profile.test";
    src.cli.commands.config --> "test/commands/config.test";
    "src/core/global-config" --> "test/commands/config.test";
    "src/core/completions/command-registry" --> "test/commands/config.test";
    "src/core/config-schema" --> "test/commands/config.test";
    src.core.profiles --> "test/commands/config.test";
    src.commands.config --> "test/commands/config.test";
    src.core.index --> "test/commands/context.test" { getGlobalDataDir, registerStore }
    "src/core/project-config" --> "test/commands/context.test" { readProjectConfig }
    "test/helpers/run-cli" --> "test/commands/context.test" { RunCLIResult, runCLI }
    "test/helpers/openspec-fixtures" --> "test/commands/context.test" { createOpenSpecRoot }
    "test/helpers/fs-snapshot" --> "test/commands/context.test" { snapshotDirectory }
    "test/helpers/temp-cleanup" --> "test/commands/context.test" { cleanupTempPath }
    src.core.index --> "test/commands/declared-store-fallback.test" {
        getGlobalDataDir,
        registerStore,
    }
    "test/helpers/run-cli" --> "test/commands/declared-store-fallback.test" { RunCLIResult, runCLI }
    "test/helpers/fs-snapshot" --> "test/commands/declared-store-fallback.test" {
        snapshotDirectory,
    }
    "test/helpers/openspec-fixtures" --> "test/commands/declared-store-fallback.test" {
        createOpenSpecRoot,
        writeSpec,
    }
    src.core.index --> "test/commands/doctor.test" { getGlobalDataDir, registerStore }
    "test/helpers/run-cli" --> "test/commands/doctor.test" { RunCLIResult, runCLI }
    "test/helpers/openspec-fixtures" --> "test/commands/doctor.test" {
        createOpenSpecRoot,
        writeSpec,
    }
    "test/helpers/fs-snapshot" --> "test/commands/doctor.test" { snapshotDirectory }
    "test/helpers/temp-cleanup" --> "test/commands/doctor.test" { cleanupTempPath }
    "test/helpers/store-git" --> "test/commands/doctor.test" { isolatedGitEnv }
    src.commands.feedback --> "test/commands/feedback.test" { FeedbackCommand }
    src.core.index --> "test/commands/global-default-store.test" { getGlobalDataDir, registerStore }
    "test/helpers/run-cli" --> "test/commands/global-default-store.test" { RunCLIResult, runCLI }
    "test/helpers/openspec-fixtures" --> "test/commands/global-default-store.test" {
        createOpenSpecRoot,
    }
    "src/commands/install-standalone" --> "test/commands/install-standalone.test" {
        checkSource,
        installStandalone,
        installerBase,
        removeCommandFor,
        resolveInstallTarget,
    }
    "src/utils/executable-path" --> "test/commands/install-standalone.test" { findCopiesOnPath }
    src.core.index --> "test/commands/legacy-groups-removed.test" {
        getGlobalDataDir,
        registerStore,
    }
    "test/helpers/run-cli" --> "test/commands/legacy-groups-removed.test" { runCLI }
    "test/helpers/store-git" --> "test/commands/legacy-groups-removed.test" {
        createHealthyOpenSpecRoot,
    }
    "test/helpers/temp-cleanup" --> "test/commands/legacy-groups-removed.test" { cleanupTempPath }
    src.core.index --> "test/commands/profile-handoffs.test" { getGlobalDataDir, registerStore }
    src.core.profiles --> "test/commands/profile-handoffs.test" {
        ALL_WORKFLOWS,
        CORE_WORKFLOWS,
        withRouter,
    }
    "src/core/shared/skill-generation" --> "test/commands/profile-handoffs.test" {
        getSkillTemplates,
    }
    "test/helpers/openspec-fixtures" --> "test/commands/profile-handoffs.test" {
        createOpenSpecRoot,
    }
    "test/helpers/run-cli" --> "test/commands/profile-handoffs.test" { runCLI }
    "test/helpers/run-cli" --> "test/commands/schema-apply-references.test" {
        cliProjectRoot,
        runCLI,
    }
    src.cli.commands.schema --> "test/commands/schema-fork-fidelity.test";
    "src/core/artifact-graph/resolver" --> "test/commands/schema-fork-fidelity.test";
    src.commands.schema --> src.cli.commands.schema;
    "src/core/artifact-graph/resolver" --> src.commands.schema {
        getPackageSchemasDir,
        getProjectSchemasDir,
        getSchemaDir,
        getUserSchemasDir,
        isSchemaDir,
        listSchemas,
    }
    "src/core/artifact-graph/schema" --> src.commands.schema {
        SchemaValidationError,
        findApplyTracksWarning,
        parseSchema,
    }
    "src/core/artifact-graph/types" --> src.commands.schema { Artifact, SchemaYaml }
    "src/core/project-config" --> src.commands.schema { resolveConfigFilePath }
    "src/utils/file-system" --> src.commands.schema { FileSystemUtils }
    "test/helpers/run-cli" --> "test/commands/schema.test" { runCLI }
    src.cli.commands.schema --> "test/commands/schema.test";
    "src/core/artifact-graph/resolver" --> "test/commands/schema.test";
    "src/core/artifact-graph/schema" --> "test/commands/schema.test";
    src.commands.schema --> "test/commands/schema.test";
    "src/core/project-config" --> "test/commands/schema.test";
    "src/core/completions/command-registry" --> "test/commands/schema.test";
    src.core.index --> "test/commands/schemas.test" { getGlobalDataDir, registerStore }
    "test/helpers/run-cli" --> "test/commands/schemas.test" { RunCLIResult, runCLI }
    "test/helpers/openspec-fixtures" --> "test/commands/schemas.test" { createOpenSpecRoot }
    "test/helpers/temp-cleanup" --> "test/commands/schemas.test" { cleanupTempPath }
    "test/helpers/run-cli" --> "test/commands/status-all.test" { runCLI }
    src.core.index --> "test/commands/store-action-context.test" { getGlobalDataDir, registerStore }
    "src/core/root-selection" --> "test/commands/store-action-context.test" {
        findDeclaringProjectRoot,
    }
    "test/helpers/run-cli" --> "test/commands/store-action-context.test" { runCLI }
    "test/helpers/openspec-fixtures" --> "test/commands/store-action-context.test" {
        createOpenSpecRoot,
    }
    src.core.index --> "test/commands/store-git.test" {
        getGlobalDataDir,
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    "test/helpers/run-cli" --> "test/commands/store-git.test" { RunCLIResult, runCLI }
    "test/helpers/store-git" --> "test/commands/store-git.test" {
        createHealthyOpenSpecRoot,
        isolatedGitEnv,
    }
    "test/helpers/temp-cleanup" --> "test/commands/store-git.test" { cleanupTempPath }
    src.cli.commands.store --> "test/commands/store-git.test";
    "src/core/completions/command-registry" --> src.cli.commands.store { COMMAND_REGISTRY }
    "src/commands/shared-output" --> src.cli.commands.store { printJson }
    src.commands.store --> src.cli.commands.store;
    src.commands.store --> src.cli.commands.store {
        StoreCommand,
        StoreJsonOptions,
        StoreRegisterOptions,
        StoreRemoveOptions,
        StoreSetupOptions,
    }
    "src/commands/shared-output" --> src.commands.store { asErrorMessage, emitFailure, printJson }
    src.core.store.index --> src.commands.store {
        SetupStoreInput,
        StoreCleanupResult,
        StoreDiagnostic,
        StoreDoctorResult,
        StoreError,
        StoreInfo,
        StoreInspection,
        StoreListResult,
        StoreMutationResult,
        doctorStores,
        listStores,
        prepareStoreCleanup,
        prepareStoreSetup,
        registerExistingStore,
        removeStore,
        resolveSetupGitEnabled,
        setupPreparedStore,
        unregisterStore,
        validateStoreId,
    }
    src.utils.interactive --> src.commands.store { isInteractive }
    "src/core/project-config" --> "test/commands/store-phantom-root.test" { classifyOpenSpecDir }
    "test/helpers/run-cli" --> "test/commands/store-phantom-root.test" { RunCLIResult, runCLI }
    "test/helpers/openspec-fixtures" --> "test/commands/store-phantom-root.test" {
        createOpenSpecRoot,
    }
    src.core.index --> "test/commands/store-references.test" { getGlobalDataDir, registerStore }
    "test/helpers/run-cli" --> "test/commands/store-references.test" { RunCLIResult, runCLI }
    "test/helpers/fs-snapshot" --> "test/commands/store-references.test" { snapshotDirectory }
    "test/helpers/openspec-fixtures" --> "test/commands/store-references.test" {
        createOpenSpecRoot,
        writeSpec,
    }
    src.core.index --> "test/commands/store-remote.test" {
        getGlobalDataDir,
        parseStoreMetadataState,
        readStoreRegistryState,
        serializeStoreMetadataState,
    }
    "test/helpers/run-cli" --> "test/commands/store-remote.test" { RunCLIResult, runCLI }
    "test/helpers/store-git" --> "test/commands/store-remote.test" {
        createHealthyOpenSpecRoot,
        isolatedGitEnv,
    }
    "test/helpers/temp-cleanup" --> "test/commands/store-remote.test" { cleanupTempPath }
    src.core.index --> "test/commands/store-remove-nested.test" {
        getGlobalDataDir,
        getStoreMetadataPath,
        readStoreRegistryState,
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    "test/helpers/run-cli" --> "test/commands/store-remove-nested.test" { RunCLIResult, runCLI }
    "test/helpers/store-git" --> "test/commands/store-remove-nested.test" {
        createHealthyOpenSpecRoot,
        isolatedGitEnv,
    }
    src.core.index --> "test/commands/store-root-selection.test" { getGlobalDataDir, registerStore }
    src.core.store.foundation --> "test/commands/store-root-selection.test" {
        writeStoreMetadataState,
    }
    "test/helpers/run-cli" --> "test/commands/store-root-selection.test" { RunCLIResult, runCLI }
    "test/helpers/temp-cleanup" --> "test/commands/store-root-selection.test" { cleanupTempPath }
    "test/helpers/openspec-fixtures" --> "test/commands/store-root-selection.test" { writeSpec }
    src.core.index --> "test/commands/store-setup-no-init-git.test" {
        getGlobalDataDir,
        getStoreMetadataPath,
        readStoreRegistryState,
    }
    "test/helpers/run-cli" --> "test/commands/store-setup-no-init-git.test" { RunCLIResult, runCLI }
    "test/helpers/store-git" --> "test/commands/store-setup-no-init-git.test" { isolatedGitEnv }
    src.core.index --> "test/commands/store.test" {
        DEFAULT_OPENSPEC_SCHEMA,
        getGlobalDataDir,
        getStoreMetadataPath,
        getStoresDir,
        readStoreMetadataState,
        readStoreRegistryState,
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    "test/helpers/run-cli" --> "test/commands/store.test" { RunCLIResult, runCLI }
    "test/helpers/store-git" --> "test/commands/store.test" { createHealthyOpenSpecRoot }
    src.cli.commands.store --> "test/commands/store.test";
    "test/helpers/run-cli" --> "test/commands/validate-unparseable-config.test" { runCLI }
    "test/helpers/run-cli" --> "test/commands/validate.enriched-output.test" { runCLI }
    src.commands.validate --> "test/commands/validate.findings.test" {
        ValidateCommand,
        projectValidationFindings,
    }
    "src/core/root-selection" --> "test/commands/validate.findings.test" {
        ResolvedOpenSpecRoot,
        resolveRootForCommand,
        toRootOutput,
    }
    src.core.validation.validator --> "test/commands/validate.findings.test" { Validator }
    "src/utils/nested-change" --> src.commands.validate {
        NESTED_CHANGE_ISSUE_MARKER,
        describeNestedChange,
        findNestedChangesIn,
    }
    src.core.validation.validator --> src.commands.validate { Validator }
    src.core.validation.types --> src.commands.validate { ValidationIssue }
    src.core.validation.constants --> src.commands.validate { VALIDATION_MESSAGES }
    "src/core/root-selection" --> src.commands.validate {
        ResolvedOpenSpecRoot,
        isStoreSelectedRoot,
        resolveRootForCommand,
        toRootOutput,
        withStoreFlag,
    }
    src.utils.interactive --> src.commands.validate {
        canRenderSpinner,
        isInteractive,
        resolveNoInteractive,
    }
    "src/utils/item-discovery" --> src.commands.validate { getSpecIds }
    src.commands.workflow.shared --> src.commands.validate { getAvailableChanges }
    src.utils.match --> src.commands.validate { nearestMatches }
    "src/utils/task-progress" --> src.commands.validate {
        SchemaGlobCache,
        getTaskProgressDetailForChange,
    }
    "src/utils/file-system" --> src.commands.validate { FileSystemUtils }
    src.core.id --> src.commands.validate { folderStyleNameProblem }
    "src/core/project-config" --> src.commands.validate { readConfigParseError }
    "test/helpers/run-cli" --> "test/commands/validate.name-guard.security.test" { runCLI }
    "test/helpers/run-cli" --> "test/commands/validate.test" { runCLI }
    "src/core/artifact-graph/instruction-loader" --> "test/commands/workflow-instructions-injection.test" {
        generateInstructions,
        loadChangeContext,
    }
    src.commands.workflow.instructions --> "test/commands/workflow-instructions-injection.test" {
        generateArchiveInstructions,
        printArchiveInstructionsText,
        printInstructionsText,
    }
    "src/core/project-config" --> "test/commands/workflow-instructions-injection.test" {
        readProjectConfig,
    }
    src.core.references --> "test/commands/workflow-instructions-injection.test" {
        escapeEnvelopeAttribute,
    }
    "src/core/artifact-graph/instruction-loader" --> "test/commands/workflow-instructions-skipped.test" {
        formatChangeStatus,
        generateInstructions,
        loadChangeContext,
    }
    src.commands.workflow.instructions --> "test/commands/workflow-instructions-skipped.test" {
        generateApplyInstructions,
        printInstructionsText,
    }
    src.commands.workflow.status --> "test/commands/workflow-instructions-skipped.test" {
        printStatusText,
    }
    "src/core/planning-home" --> src.commands.workflow.status { getChangeDir }
    "src/core/root-selection" --> src.commands.workflow.status {
        findDeclaringProjectRoot,
        isStoreSelectedRoot,
        resolveRootForCommand,
        toPlanningHome,
        toRootOutput,
        withStoreFlag,
    }
    "src/core/artifact-graph/index" --> src.commands.workflow.status {
        ChangeStatus,
        formatChangeStatus,
        loadChangeContext,
    }
    "src/core/change-status-policy" --> src.commands.workflow.status { resolveNextStep }
    "src/commands/shared-output" --> src.commands.workflow.status { asStatus }
    "src/utils/nested-change" --> src.commands.workflow.status {
        describeNestedChange,
        findNestedChanges,
    }
    src.core.store.errors --> src.commands.workflow.status { StoreDiagnostic }
    src.commands.workflow.shared --> src.commands.workflow.status {
        getAvailableChanges,
        getStatusColor,
        getStatusIndicator,
        validateChangeExists,
        validateSchemaExists,
    }
    "src/core/global-config" --> "test/commands/workset.test" { getGlobalDataDir }
    src.core.worksets --> "test/commands/workset.test" {
        getWorksetCodeWorkspacePath,
        getWorksetsFilePath,
    }
    src.commands.workset --> "test/commands/workset.test" { exitCodeForLaunch, launchOpenerCommand }
    "test/helpers/run-cli" --> "test/commands/workset.test" { RunCLIResult, runCLI }
    "test/helpers/fake-tool" --> "test/commands/workset.test" {
        createFakeTool,
        envWithFakeTools,
        readLaunchLog,
    }
    "test/helpers/fs-snapshot" --> "test/commands/workset.test" { snapshotDirectory }
    "test/helpers/temp-cleanup" --> "test/commands/workset.test" { cleanupTempPath }
    src.cli.commands.workset --> "test/commands/workset.test";
    src.core.worksets --> src.commands.workset {
        Workset,
        WorksetMember,
        buildWorksetCodeWorkspaceJson,
        getWorkset,
        getWorksetCodeWorkspacePath,
        listWorksets,
        readWorksetsState,
        removeWorkset,
        updateWorksetsState,
        validateWorksetName,
        withWorkset,
        withWorksetsLock,
        worksetNotFoundError,
    }
    src.core.openers --> src.commands.workset {
        LaunchCommand,
        OpenerDefinition,
        buildLaunchCommand,
        findOpener,
        isOpenerCommandAvailable,
        isOpenerEnabled,
        listOpenerChoices,
        mergeOpenerTable,
    }
    "src/core/file-state" --> src.commands.workset { pathIsDirectory, writeFileAtomically }
    "src/core/global-config" --> src.commands.workset { getGlobalConfig, getGlobalConfigPath }
    src.core.store.errors --> src.commands.workset { StoreError }
    src.utils.interactive --> src.commands.workset { isInteractive }
    "src/commands/shared-output" --> src.commands.workset {
        asErrorMessage,
        emitFailure,
        isPromptCancellationError,
        printJson,
    }
    "src/commands/workset-input" --> src.commands.workset {
        finalizeWorkset,
        firstInstalledAlternative,
        formatMemberRows,
        noToolInstalledError,
        resolveMemberFlags,
        toolUnavailableError,
        toolUnknownError,
    }
    "src/commands/workset-prompts" --> src.commands.workset {
        composeInteractively,
        confirmRemoveInteractively,
        promptOpenNow,
        promptToolFromChoices,
    }
    "src/core/file-state" --> "src/commands/workset-input" { pathIsDirectory }
    src.core.openers --> "src/commands/workset-input" {
        OpenerDefinition,
        OpenerScanOptions,
        findOpener,
        isOpenerCommandAvailable,
        isOpenerEnabled,
    }
    src.core.store.errors --> "src/commands/workset-input" { StoreError }
    src.core.store.operations --> "src/commands/workset-input" { expandUserPath }
    "src/core/global-config" --> "src/commands/workset-input" { getGlobalConfigPath }
    src.core.worksets --> "src/commands/workset-input" {
        Workset,
        WorksetMember,
        memberLabelProblem,
        memberListProblem,
    }
    "src/core/file-state" --> "src/commands/workset-prompts" { pathIsDirectory }
    src.core.openers --> "src/commands/workset-prompts" {
        OpenerChoice,
        OpenerDefinition,
        listOpenerChoices,
    }
    src.core.store.operations --> "src/commands/workset-prompts" { expandUserPath }
    src.core.worksets --> "src/commands/workset-prompts" {
        Workset,
        WorksetMember,
        memberLabelProblem,
        validateWorksetName,
    }
    "src/commands/shared-output" --> "src/commands/workset-prompts" { asErrorMessage }
    "src/commands/workset-input" --> "src/commands/workset-prompts" {
        assertKnownTool,
        finalizeWorkset,
        formatMemberRows,
        resolveMemberFlags,
    }
    "src/core/completions/command-registry" --> src.cli.commands.workset { COMMAND_REGISTRY }
    src.core.store.errors --> src.cli.commands.workset { StoreDiagnostic }
    "src/commands/shared-output" --> src.cli.commands.workset { printJson }
    src.commands.workset --> src.cli.commands.workset;
    src.commands.workset --> src.cli.commands.workset {
        WorksetCommand,
        WorksetCreateOptions,
        WorksetOpenOptions,
        WorksetRemoveOptions,
    }
    src.core.archive --> "test/core/archive.test" { ArchiveCommand, isRetirableSpec }
    "src/core/specs-apply" --> "test/core/archive.test" { retireSpec }
    src.core.validation.validator --> "test/core/archive.test" { Validator }
    "src/core/parsers/markdown-parser" --> "test/core/archive.test" { MarkdownParser }
    "src/core/parsers/spec-structure" --> "test/core/archive.test" { findMainSpecStructureIssues }
    src.core.validation.constants --> "test/core/archive.test" { VALIDATION_MESSAGES }
    src.utils.date --> "test/core/archive.test" { formatLocalDate }
    src.utils.interactive --> "test/core/archive.test";
    src.utils.date --> src.core.archive { formatLocalDate }
    "src/utils/task-progress" --> src.core.archive { formatTaskStatus, getTaskProgressForChange }
    src.core.validation.validator --> src.core.archive { Validator }
    src.core.validation.constants --> src.core.archive { VALIDATION_MESSAGES }
    "src/core/root-selection" --> src.core.archive {
        ResolvedOpenSpecRoot,
        emitStoreRootBanner,
        isRootSelectionError,
        isStoreSelectedRoot,
        resolveOpenSpecRoot,
        toRootOutput,
        withStoreFlag,
    }
    "src/core/specs-apply" --> src.core.archive {
        SpecUpdate,
        buildUpdatedSpec,
        finalizeRetiredSpec,
        findSpecUpdates,
        pruneEmptyDirs,
        retireSpec,
        writeUpdatedSpec,
    }
    "src/utils/spec-discovery" --> src.core.archive {
        discoverSpecFiles,
        findUnreadDeltaFiles,
        hasAnyFileUnder,
    }
    "src/utils/change-metadata" --> src.core.archive {
        METADATA_FILENAME,
        formatUnknownChangeMetadataKeysMessage,
        readRetireCapabilitiesMarker,
        readSkipSpecsMarker,
        readUnknownChangeMetadataKeys,
    }
    src.utils.interactive --> src.core.archive { confirmPrompt, isNonInteractivePromptError }
    "src/utils/file-system" --> src.core.archive { FileSystemUtils }
    src.core.id --> src.core.archive { folderStyleNameProblem }
    "src/utils/nested-change" --> src.core.archive { describeNestedChange, findNestedChangesIn }
    "src/core/artifact-graph/graph" --> "test/core/artifact-graph/graph.test" { ArtifactGraph }
    "src/core/artifact-graph/types" --> "test/core/artifact-graph/graph.test" { SchemaYaml }
    "src/core/artifact-graph/schema" --> "test/core/artifact-graph/instruction-loader.test" {
        parseSchema,
    }
    "src/core/artifact-graph/instruction-loader" --> "test/core/artifact-graph/instruction-loader.test" {
        TemplateLoadError,
        formatChangeStatus,
        generateInstructions,
        loadChangeContext,
        loadTemplate,
    }
    "src/utils/file-system" --> "test/core/artifact-graph/outputs.test" { FileSystemUtils }
    "src/core/artifact-graph/outputs" --> "test/core/artifact-graph/outputs.test" {
        artifactOutputExists,
        isGlobPattern,
        isSpecsArtifactPath,
        resolveArtifactOutputs,
    }
    "src/core/artifact-graph/resolver" --> "test/core/artifact-graph/resolver.test";
    "src/core/artifact-graph/resolver" --> "test/core/artifact-graph/resolver.test" {
        SchemaLoadError,
        getPackageSchemasDir,
        getProjectSchemasDir,
        getSchemaDir,
        getUserSchemasDir,
        isSchemaDir,
        listSchemas,
        listSchemasWithInfo,
        resolveSchema,
    }
    "src/core/artifact-graph/schema" --> "test/core/artifact-graph/schema-apply-references.test" {
        SchemaValidationError,
        findApplyTracksWarning,
        parseSchema,
    }
    "test/helpers/run-cli" --> "test/core/artifact-graph/schema-apply-references.test" {
        cliProjectRoot,
    }
    "src/core/artifact-graph/schema" --> "test/core/artifact-graph/schema.test" {
        SchemaValidationError,
        parseSchema,
    }
    "src/core/artifact-graph/state" --> "test/core/artifact-graph/state.test" { detectCompleted }
    "src/core/artifact-graph/graph" --> "test/core/artifact-graph/state.test" { ArtifactGraph }
    "src/core/artifact-graph/types" --> "test/core/artifact-graph/state.test" { SchemaYaml }
    "src/core/artifact-graph/resolver" --> "test/core/artifact-graph/workflow.integration.test" {
        resolveSchema,
    }
    "src/core/artifact-graph/graph" --> "test/core/artifact-graph/workflow.integration.test" {
        ArtifactGraph,
    }
    "src/core/artifact-graph/state" --> "test/core/artifact-graph/workflow.integration.test" {
        detectCompleted,
    }
    "src/core/artifact-graph/types" --> "test/core/artifact-graph/workflow.integration.test" {
        BlockedArtifacts,
    }
    "src/core/available-tools" --> "test/core/available-tools.test" { getAvailableTools }
    "src/core/change-status-policy" --> "test/core/change-status-policy.test" {
        ChangeNextStepsInput,
        ChangeStatusPolicyArtifact,
        buildNextSteps,
        resolveNextStep,
    }
    src.cli.index --> "test/core/cli-is-json-run.test" {
        isCompletionRun,
        isJsonRun,
        isTabCompletionRun,
        shouldDeferCompletionTip,
    }
    src.core.archive --> src.cli.index;
    src.core.archive --> src.cli.index { ArchiveOptions }
    src.cli.commands.spec --> src.cli.index { registerSpecCommand }
    src.cli.commands.config --> src.cli.index { registerConfigCommand }
    src.cli.commands.schema --> src.cli.index { registerSchemaCommand }
    src.cli.commands.store --> src.cli.index { registerStoreCommand }
    src.cli.commands.doctor --> src.cli.index { registerDoctorCommand }
    src.cli.commands.context --> src.cli.index { registerContextCommand }
    src.cli.commands.workset --> src.cli.index { registerWorksetCommand }
    "src/commands/workflow/default-schema" --> src.cli.index { DEFAULT_SCHEMA }
    src.commands.workflow.index --> src.cli.index {
        InstructionsOptions,
        NewChangeOptions,
        SchemasOptions,
        StatusOptions,
        TemplatesOptions,
    }
    "src/core/completions/shared-flags" --> src.cli.index { COMMON_FLAGS }
    "src/commands/shared-output" --> src.cli.index;
    "src/core/version-check" --> src.cli.index;
    src.telemetry.index --> src.cli.index;
    "src/core/completion-tip" --> src.cli.index;
    src.core.config --> src.cli.index;
    src.core.init --> src.cli.index;
    src.core.update --> src.cli.index;
    "src/core/update-plan" --> src.cli.index;
    src.utils.interactive --> src.cli.index;
    "src/core/standalone-tip" --> src.cli.index;
    "src/commands/install-standalone" --> src.cli.index;
    "src/core/root-selection" --> src.cli.index;
    src.core.list --> src.cli.index;
    src.core.view --> src.cli.index;
    src.commands.change --> src.cli.index;
    src.commands.validate --> src.cli.index;
    src.commands.show --> src.cli.index;
    src.commands.feedback --> src.cli.index;
    src.commands.completion --> src.cli.index;
    src.commands.workflow.status --> src.cli.index;
    src.commands.workflow.instructions --> src.cli.index;
    src.commands.workflow.templates --> src.cli.index;
    src.commands.workflow.schemas --> src.cli.index;
    "src/commands/workflow/new-change" --> src.cli.index;
    src.commands.spec --> src.cli.commands.spec;
    src.commands.spec --> src.cli.commands.spec { ShowOptions }
    "src/core/parsers/markdown-parser" --> src.commands.spec { MarkdownParser }
    src.core.validation.validator --> src.commands.spec { Validator }
    src.core.schemas.index --> src.commands.spec { Spec }
    "src/core/root-selection" --> src.commands.spec { RootOutput }
    src.utils.interactive --> src.commands.spec { isInteractive }
    "src/utils/item-discovery" --> src.commands.spec { getSpecIds }
    "src/utils/spec-discovery" --> src.commands.spec { discoverSpecFiles }
    "src/utils/spec-path-containment" --> src.commands.spec { assertDiscoveredSpecFile }
    "src/core/completions/command-registry" --> src.cli.commands.doctor { COMMAND_REGISTRY }
    "src/core/completions/shared-flags" --> src.cli.commands.doctor { COMMON_FLAGS }
    src.commands.doctor --> src.cli.commands.doctor;
    src.commands.doctor --> src.cli.commands.doctor { DoctorOptions }
    "src/core/root-selection" --> src.commands.doctor {
        ResolvedOpenSpecRoot,
        resolveRootForCommand,
    }
    src.core.store.foundation --> src.commands.doctor { readOptionalStoreMetadataState }
    src.core.store.git --> src.commands.doctor {
        gitOriginUrl,
        gitTrackingDrift,
        isGitRepositoryAtRoot,
    }
    "src/core/project-config" --> src.commands.doctor {
        classifyOpenSpecDir,
        readProjectConfig,
        resolveConfigFilePath,
    }
    "src/core/planning-home" --> src.commands.doctor { findRepoPlanningRootSync }
    "src/commands/shared-gather" --> src.commands.doctor { gatherRelationshipData }
    "src/core/relationship-health" --> src.commands.doctor {
        InspectRelationshipsInput,
        RelationshipHealth,
        inspectRelationships,
    }
    "src/commands/shared-output" --> src.commands.doctor { emitFailure, printJson }
    src.core.store.registry --> "src/commands/shared-gather" {
        RegistrySnapshot,
        readRegistrySnapshot,
    }
    "src/core/project-config" --> "src/commands/shared-gather" {
        ProjectConfig,
        readProjectConfig,
        resolveConfigFilePath,
    }
    src.core.references --> "src/commands/shared-gather" {
        ReferenceIndexEntry,
        assembleReferenceIndex,
    }
    "src/core/openspec-root" --> "src/commands/shared-gather" {
        OpenSpecRootInspection,
        inspectOpenSpecRoot,
    }
    "src/core/root-selection" --> "src/commands/shared-gather" { ResolvedOpenSpecRoot }
    src.core.store.errors --> "src/core/relationship-health" {
        StoreDiagnostic,
        makeStoreDiagnostic,
    }
    src.core.references --> "src/core/relationship-health" { ReferenceIndexEntry, sanitizeInline }
    "src/core/project-config" --> "src/core/relationship-health" { storePointerProblem }
    "src/core/root-selection" --> "src/core/relationship-health" {
        ResolvedOpenSpecRoot,
        toRootOutput,
    }
    "src/core/completions/command-registry" --> src.cli.commands.context { COMMAND_REGISTRY }
    "src/core/completions/shared-flags" --> src.cli.commands.context { COMMON_FLAGS }
    src.commands.context --> src.cli.commands.context;
    src.commands.context --> src.cli.commands.context { ContextOptions }
    "src/core/root-selection" --> src.commands.context {
        ResolvedOpenSpecRoot,
        resolveRootForCommand,
    }
    "src/core/relationship-health" --> src.commands.context { inspectRelationships }
    "src/core/working-set" --> src.commands.context {
        WorkingSet,
        WorkingSetMember,
        assembleWorkingSet,
        buildCodeWorkspaceJson,
        isAvailableMember,
    }
    src.core.store.errors --> src.commands.context { StoreError }
    "src/commands/shared-output" --> src.commands.context { emitFailure, printJson }
    "src/commands/shared-gather" --> src.commands.context { gatherRelationshipData }
    src.core.store.errors --> "src/core/working-set" { StoreDiagnostic }
    src.core.references --> "src/core/working-set" { ReferenceIndexEntry, fetchRecipe }
    "src/core/root-selection" --> "src/core/working-set" { ResolvedOpenSpecRoot, toRootOutput }
    src.commands.workflow.status --> src.commands.workflow.index {
        BATCH_STATUS_FAILURE_PAYLOAD,
        StatusOptions,
        statusCommand,
    }
    src.commands.workflow.instructions --> src.commands.workflow.index {
        InstructionsOptions,
        applyInstructionsCommand,
        archiveInstructionsCommand,
        instructionsCommand,
    }
    src.commands.workflow.templates --> src.commands.workflow.index {
        TemplatesOptions,
        templatesCommand,
    }
    src.commands.workflow.schemas --> src.commands.workflow.index { SchemasOptions, schemasCommand }
    "src/commands/workflow/new-change" --> src.commands.workflow.index {
        NewChangeOptions,
        newChangeCommand,
    }
    src.commands.workflow.shared --> src.commands.workflow.index { DEFAULT_SCHEMA }
    "src/core/artifact-graph/index" --> src.commands.workflow.templates {
        ArtifactGraph,
        getSchemaDir,
        resolveSchema,
    }
    "src/utils/file-system" --> src.commands.workflow.templates { FileSystemUtils }
    src.commands.workflow.shared --> src.commands.workflow.templates {
        DEFAULT_SCHEMA,
        validateSchemaExists,
    }
    "src/core/artifact-graph/resolver" --> src.commands.workflow.templates;
    "src/core/artifact-graph/index" --> src.commands.workflow.schemas { listSchemasWithInfo }
    "src/core/root-selection" --> src.commands.workflow.schemas { resolveRootForCommand }
    "src/utils/change-utils" --> "src/commands/workflow/new-change" {
        createChange,
        validateChangeName,
    }
    "src/core/planning-home" --> "src/commands/workflow/new-change" { formatChangeLocation }
    "src/core/root-selection" --> "src/commands/workflow/new-change" {
        ResolvedOpenSpecRoot,
        RootOutput,
        RootSelectionError,
        isStoreSelectedRoot,
        resolveRootForCommand,
        toPlanningHome,
        toRootOutput,
        withStoreFlag,
    }
    "src/core/project-config" --> "src/commands/workflow/new-change" { readProjectConfig }
    src.commands.workflow.shared --> "src/commands/workflow/new-change" {
        printJson,
        statusFromError,
        validateSchemaExists,
    }
    "src/utils/file-system" --> "src/utils/change-utils" { FileSystemUtils }
    "src/utils/change-metadata" --> "src/utils/change-utils" {
        validateSchemaName,
        writeChangeMetadata,
    }
    src.utils.date --> "src/utils/change-utils" { formatLocalDate }
    "src/core/project-config" --> "src/utils/change-utils" { readProjectConfig }
    src.core.id --> "src/utils/change-utils" { isKebabId }
    "src/core/artifact-graph/resolver" --> "src/utils/change-utils" { resolveSchema }
    "src/core/artifact-graph/outputs" --> "src/utils/change-utils" { isSpecsArtifactPath }
    "src/core/change-metadata/index" --> "src/utils/change-utils" { ChangeMetadata }
    src.utils.ci --> "src/core/standalone-tip" { isCiEnvironment }
    "src/core/completion-tip" --> "src/core/standalone-tip" { markConfigFlag, readRawConfig }
    "src/core/version-check" --> "src/core/standalone-tip" {
        getCliInstallInfo,
        getStandaloneBinaryPath,
    }
    "src/utils/task-progress" --> src.core.list { formatTaskStatus, getTaskProgressForChange }
    "src/core/parsers/markdown-parser" --> src.core.list { MarkdownParser }
    "src/core/root-selection" --> src.core.list { RootOutput }
    "src/utils/spec-discovery" --> src.core.list { discoverSpecFiles }
    "src/utils/nested-change" --> src.core.list {
        NestedChangeFinding,
        describeNestedChange,
        findNestedChanges,
    }
    "src/utils/task-progress" --> src.core.view { getTaskProgressForChange }
    "src/core/parsers/markdown-parser" --> src.core.view { MarkdownParser }
    "src/utils/spec-discovery" --> src.core.view { discoverSpecFiles }
    "src/core/artifact-graph/index" --> src.core.view {
        ChangeStatus,
        formatChangeStatus,
        loadChangeContext,
    }
    "src/core/converters/json-converter" --> src.commands.change { JsonConverter }
    src.core.validation.validator --> src.commands.change { Validator }
    src.core.validation.constants --> src.commands.change { VALIDATION_MESSAGES }
    "src/core/parsers/change-parser" --> src.commands.change { ChangeParser }
    src.core.schemas.index --> src.commands.change { Change, Delta }
    "src/core/root-selection" --> src.commands.change { RootOutput }
    src.utils.interactive --> src.commands.change { isInteractive }
    "src/utils/item-discovery" --> src.commands.change { getActiveChangeIds }
    "src/utils/nested-change" --> src.commands.change { describeNestedChange, findNestedChangesIn }
    "src/utils/task-progress" --> src.commands.change { getTaskProgressForChange }
    "src/utils/file-system" --> src.commands.change { FileSystemUtils }
    "src/utils/spec-path-containment" --> src.commands.change { assertDiscoveredSpecFile }
    "src/utils/spec-discovery" --> src.commands.change { discoverSpecFiles }
    "src/core/parsers/requirement-blocks" --> src.commands.change {
        foldRequirementName,
        parseDeltaSpec,
    }
    "src/utils/requirement-diff" --> src.commands.change {
        buildRenameMap,
        diffRequirementBlock,
        extractRequirementBlock,
    }
    src.utils.interactive --> src.commands.show { isInteractive }
    "src/utils/item-discovery" --> src.commands.show { getActiveChangeIds, getSpecIds }
    "src/core/root-selection" --> src.commands.show {
        ResolvedOpenSpecRoot,
        RootOutput,
        isStoreSelectedRoot,
        resolveRootForCommand,
        toRootOutput,
        withStoreFlag,
    }
    src.commands.change --> src.commands.show { ChangeCommand }
    src.commands.spec --> src.commands.show { SpecCommand }
    src.utils.match --> src.commands.show { nearestMatches }
    "src/core/command-generation/adapters/amazon-q" --> "test/core/command-generation/adapters.test" {
        amazonQAdapter,
    }
    "src/core/command-generation/adapters/antigravity" --> "test/core/command-generation/adapters.test" {
        antigravityAdapter,
    }
    "src/core/command-generation/adapters/atomcode" --> "test/core/command-generation/adapters.test" {
        atomcodeAdapter,
    }
    "src/core/command-generation/adapters/auggie" --> "test/core/command-generation/adapters.test" {
        auggieAdapter,
    }
    "src/core/command-generation/adapters/bob" --> "test/core/command-generation/adapters.test" {
        bobAdapter,
    }
    "src/core/command-generation/adapters/claude" --> "test/core/command-generation/adapters.test" {
        claudeAdapter,
    }
    "src/core/command-generation/adapters/cline" --> "test/core/command-generation/adapters.test" {
        clineAdapter,
    }
    "src/core/command-generation/adapters/command-code" --> "test/core/command-generation/adapters.test" {
        commandCodeAdapter,
    }
    "src/core/command-generation/adapters/codebuddy" --> "test/core/command-generation/adapters.test" {
        codebuddyAdapter,
    }
    "src/core/command-generation/adapters/codestudio" --> "test/core/command-generation/adapters.test" {
        codeStudioAdapter,
    }
    "src/core/command-generation/adapters/continue" --> "test/core/command-generation/adapters.test" {
        continueAdapter,
    }
    "src/core/command-generation/adapters/costrict" --> "test/core/command-generation/adapters.test" {
        costrictAdapter,
    }
    "src/core/command-generation/adapters/crush" --> "test/core/command-generation/adapters.test" {
        crushAdapter,
    }
    "src/core/command-generation/adapters/cursor" --> "test/core/command-generation/adapters.test" {
        cursorAdapter,
    }
    "src/core/command-generation/adapters/devin" --> "test/core/command-generation/adapters.test" {
        devinAdapter,
    }
    "src/core/command-generation/adapters/easycode" --> "test/core/command-generation/adapters.test" {
        easycodeAdapter,
    }
    "src/core/command-generation/adapters/factory" --> "test/core/command-generation/adapters.test" {
        factoryAdapter,
    }
    "src/core/command-generation/adapters/gemini" --> "test/core/command-generation/adapters.test" {
        geminiAdapter,
    }
    "src/core/command-generation/adapters/github-copilot" --> "test/core/command-generation/adapters.test" {
        githubCopilotAdapter,
    }
    "src/core/command-generation/adapters/gigacode" --> "test/core/command-generation/adapters.test" {
        gigacodeAdapter,
    }
    "src/core/command-generation/adapters/iflow" --> "test/core/command-generation/adapters.test" {
        iflowAdapter,
    }
    "src/core/command-generation/adapters/junie" --> "test/core/command-generation/adapters.test" {
        junieAdapter,
    }
    "src/core/command-generation/adapters/kilocode" --> "test/core/command-generation/adapters.test" {
        kilocodeAdapter,
    }
    "src/core/command-generation/adapters/kiro" --> "test/core/command-generation/adapters.test" {
        kiroAdapter,
    }
    "src/core/command-generation/adapters/lingma" --> "test/core/command-generation/adapters.test" {
        lingmaAdapter,
    }
    "src/core/command-generation/adapters/oh-my-pi" --> "test/core/command-generation/adapters.test" {
        ohMyPiAdapter,
    }
    "src/core/command-generation/adapters/opencode" --> "test/core/command-generation/adapters.test" {
        opencodeAdapter,
    }
    "src/core/command-generation/adapters/pi" --> "test/core/command-generation/adapters.test" {
        piAdapter,
    }
    "src/core/command-generation/adapters/qoder" --> "test/core/command-generation/adapters.test" {
        qoderAdapter,
    }
    "src/core/command-generation/adapters/qwen" --> "test/core/command-generation/adapters.test" {
        qwenAdapter,
    }
    "src/core/command-generation/adapters/roocode" --> "test/core/command-generation/adapters.test" {
        roocodeAdapter,
    }
    "src/core/command-generation/adapters/trae" --> "test/core/command-generation/adapters.test" {
        traeAdapter,
    }
    "src/core/command-generation/adapters/codeassistant" --> "test/core/command-generation/adapters.test" {
        codeassistantAdapter,
    }
    "src/core/command-generation/adapters/zcode" --> "test/core/command-generation/adapters.test" {
        zcodeAdapter,
    }
    "src/core/command-generation/types" --> "test/core/command-generation/adapters.test" {
        CommandContent,
        ToolCommandAdapter,
    }
    "src/core/command-generation/registry" --> "test/core/command-generation/adapters.test" {
        CommandAdapterRegistry,
    }
    "src/core/command-generation/generator" --> "test/core/command-generation/adapters.test" {
        generateCommand,
    }
    "src/core/shared/skill-generation" --> "test/core/command-generation/adapters.test" {
        getCommandContents,
    }
    "src/core/command-generation/generator" --> "test/core/command-generation/generator.test" {
        generateCommand,
        generateCommands,
    }
    "src/core/command-generation/adapters/claude" --> "test/core/command-generation/generator.test" {
        claudeAdapter,
    }
    "src/core/command-generation/adapters/cursor" --> "test/core/command-generation/generator.test" {
        cursorAdapter,
    }
    "src/core/command-generation/types" --> "test/core/command-generation/generator.test" {
        CommandContent,
        ToolCommandAdapter,
    }
    "src/core/command-generation/invocation" --> "test/core/command-generation/invocation.test" {
        formatCommandInvocation,
        getInvocationForAdapter,
        getInvocationStyleForPath,
        needsInvocationRewrite,
    }
    "src/core/command-generation/registry" --> "test/core/command-generation/invocation.test" {
        CommandAdapterRegistry,
    }
    "src/core/command-surface" --> "test/core/command-generation/invocation.test" {
        resolveCommandInvocation,
    }
    "src/core/command-generation/generator" --> "test/core/command-generation/invocation.test" {
        generateCommand,
    }
    "src/core/command-generation/types" --> "test/core/command-generation/invocation.test" {
        CommandContent,
    }
    src.core.profiles --> "test/core/command-generation/invocation.test" { ALL_WORKFLOWS }
    "src/core/command-generation/registry" --> "test/core/command-generation/registry.test" {
        CommandAdapterRegistry,
    }
    "src/core/command-surface" --> "test/core/command-generation/registry.test" {
        resolveCommandSurfaceCapability,
    }
    "src/core/command-generation/types" --> "test/core/command-generation/types.test" {
        CommandContent,
        GeneratedCommand,
        ToolCommandAdapter,
    }
    "src/core/command-generation/yaml" --> "test/core/command-generation/yaml.test" {
        escapeYamlValue,
    }
    "src/core/shared/command-reconcile" --> "test/core/command-reconcile.test" {
        formatKeptCommandFiles,
        reconcileCommandFiles,
    }
    "src/core/shared/skill-generation" --> "test/core/command-reconcile.test" { getCommandContents }
    "src/core/command-generation/index" --> "test/core/command-reconcile.test" {
        CommandAdapterRegistry,
        generateCommands,
    }
    src.core.profiles --> "test/core/command-reconcile.test" { ALL_WORKFLOWS }
    src.commands.change --> "test/core/commands/change-command.list.test" { ChangeCommand }
    src.commands.change --> "test/core/commands/change-command.show-validate.test" { ChangeCommand }
    src.commands.spec --> "test/core/commands/spec-command.security.test" { SpecCommand }
    "src/core/completion-tip" --> "test/core/completion-tip.atomic-write.security.test" {
        maybeShowCompletionTip,
    }
    "src/core/global-config" --> "test/core/completion-tip.atomic-write.security.test" {
        getGlobalConfigPath,
    }
    "src/core/completion-tip" --> "test/core/completion-tip.test" {
        COMPLETION_TIP_MESSAGE,
        maybeShowCompletionTip,
    }
    "src/core/global-config" --> "test/core/completion-tip.test" { getGlobalConfigPath }
    "src/core/completions/command-registry" --> "test/core/completions/command-registry.test" {
        COMMAND_REGISTRY,
    }
    "src/core/completions/shared-flags" --> "test/core/completions/command-registry.test" {
        COMMON_FLAGS,
    }
    "src/core/templates/workflows/store-selection" --> "test/core/completions/command-registry.test" {
        STORE_SELECTION_GUIDANCE,
    }
    src.cli.index --> "test/core/completions/command-registry.test" { getCommandPath, program }
    src.core.completions.types --> "test/core/completions/command-registry.test" {
        CommandDefinition,
        FlagDefinition,
        PositionalDefinition,
    }
    "src/core/completions/completion-provider" --> "test/core/completions/completion-provider.test" {
        CompletionProvider,
    }
    "src/core/completions/generators/bash-generator" --> "test/core/completions/generators/bash-generator.test" {
        BashGenerator,
    }
    src.core.completions.types --> "test/core/completions/generators/bash-generator.test" {
        CommandDefinition,
    }
    "src/core/completions/generators/fish-generator" --> "test/core/completions/generators/fish-generator.test" {
        FishGenerator,
    }
    src.core.completions.types --> "test/core/completions/generators/fish-generator.test" {
        CommandDefinition,
    }
    "src/core/completions/command-registry" --> "test/core/completions/generators/fish-generator.test" {
        COMMAND_REGISTRY,
    }
    "src/core/completions/generators/powershell-generator" --> "test/core/completions/generators/powershell-generator.test" {
        PowerShellGenerator,
    }
    "src/core/completions/command-registry" --> "test/core/completions/generators/powershell-generator.test" {
        COMMAND_REGISTRY,
    }
    src.core.completions.types --> "test/core/completions/generators/powershell-generator.test" {
        CommandDefinition,
    }
    "src/core/completions/generators/zsh-generator" --> "test/core/completions/generators/zsh-generator.test" {
        ZshGenerator,
    }
    src.core.completions.types --> "test/core/completions/generators/zsh-generator.test" {
        CommandDefinition,
    }
    "src/core/completions/installers/bash-installer" --> "test/core/completions/installers/bash-installer.round-trip.test" {
        BashInstaller,
    }
    "test/helpers/run-cli" --> "test/core/completions/installers/bash-installer.round-trip.test" {
        runCLI,
    }
    "src/core/completions/installers/bash-installer" --> "test/core/completions/installers/bash-installer.test" {
        BashInstaller,
    }
    "src/core/completions/installers/fish-installer" --> "test/core/completions/installers/fish-installer.test" {
        FishInstaller,
    }
    "src/core/completions/installers/powershell-installer" --> "test/core/completions/installers/powershell-installer.test" {
        PowerShellInstaller,
    }
    "src/core/completions/installers/zsh-installer" --> "test/core/completions/installers/zsh-installer.round-trip.test" {
        ZshInstaller,
    }
    "src/core/completions/installers/zsh-installer" --> "test/core/completions/installers/zsh-installer.test" {
        ZshInstaller,
    }
    "src/core/completions/command-registry" --> "test/core/completions/validation-report.test" {
        COMMAND_REGISTRY,
    }
    src.core.completions.factory --> "test/core/completions/validation-report.test" {
        CompletionFactory,
    }
    "src/core/config-prompts" --> "test/core/config-prompts.test" { serializeConfig }
    "src/core/config-schema" --> "test/core/config-schema.test" {
        DEFAULT_CONFIG,
        GlobalConfigSchema,
        coerceValue,
        deleteNestedValue,
        formatValueYaml,
        getNestedValue,
        hasUnsafeKeySegment,
        setNestedValue,
        validateConfig,
        validateConfigKeyPath,
    }
    "src/core/converters/json-converter" --> "test/core/converters/json-converter.test" {
        JsonConverter,
    }
    "src/core/file-state" --> "test/core/file-state.test" {
        acquireFileLock,
        releaseFileLock,
        writeFileAtomically,
    }
    src.core.store.index --> "test/core/file-state.test" { updateStoreRegistryState }
    "src/core/github-copilot/cloud-agent" --> "test/core/github-copilot-cloud-agent.test" {
        COPILOT_CLOUD_FILES,
        findUnmanagedCloudFiles,
        generateCopilotAgentFile,
        generateCopilotSetupSteps,
        hasExistingManagedCloudFiles,
        includesGitHubCopilot,
        isCopilotCloudEnabled,
        listManagedCloudFiles,
        persistCopilotCloudOptIn,
        readCopilotCloudOptIn,
        removeCopilotCloudFiles,
        writeCopilotCloudFiles,
    }
    "src/core/global-config" --> "test/core/global-config.test" {
        Delivery,
        GLOBAL_CONFIG_DIR_NAME,
        GLOBAL_CONFIG_FILE_NAME,
        Profile,
        getGlobalConfig,
        getGlobalConfigDir,
        getGlobalConfigPath,
        getGlobalDataDir,
        saveGlobalConfig,
    }
    "test/helpers/run-cli" --> "test/core/global-config.unparseable.test" { runCLI }
    src.telemetry.index --> "test/core/global-config.unparseable.test";
    "src/core/global-config" --> "test/core/global-config.unparseable.test";
    src.telemetry.config --> "test/core/global-config.unparseable.test";
    src.cli.commands.config --> "test/core/global-config.unparseable.test";
    "test/helpers/run-cli" --> "test/core/global-skills.test" { cliProjectRoot, runCLI }
    "src/core/command-generation/index" --> "test/core/global-skills.test" {
        CommandAdapterRegistry,
        generateCommands,
    }
    "src/core/shared/skill-generation" --> "test/core/global-skills.test" { getCommandContents }
    "scripts/skillssh-shared" --> "test/core/global-skills.test" { stripVolatileFrontmatter }
    src.core.init --> "test/core/init.test" { InitCommand }
    "src/core/global-config" --> "test/core/init.test" { getGlobalConfig, saveGlobalConfig }
    "src/core/project-config" --> "test/core/init.test" { MAX_CONTEXT_SIZE, readProjectConfig }
    "src/utils/file-system" --> "test/core/init.test" { FileSystemUtils }
    src.core.profiles --> "test/core/init.test" { ALL_WORKFLOWS }
    "src/core/shared/skill-generation" --> "test/core/init.test" { getCommandContents }
    "src/core/command-generation/index" --> "test/core/init.test" {
        CommandAdapterRegistry,
        generateCommands,
    }
    "test/helpers/released-codex-prompt" --> "test/core/init.test" { releasedCodexPrompt }
    "test/helpers/run-cli" --> "test/core/known-projects.test" { cliProjectRoot, runCLI }
    "src/core/known-projects" --> "test/core/known-projects.test" {
        knownProjectsPath,
        readKnownProjects,
        rememberProject,
    }
    "src/core/legacy-cleanup" --> "test/core/legacy-cleanup.test" {
        LEGACY_CONFIG_FILES,
        LEGACY_GLOBAL_SLASH_COMMAND_PATHS,
        LEGACY_SLASH_COMMAND_PATHS,
        cleanupLegacyArtifacts,
        detectLegacyArtifacts,
        detectLegacyConfigFiles,
        detectLegacySlashCommands,
        detectLegacyStructureFiles,
        formatCleanupSummary,
        formatDeferredGlobalPromptSummary,
        formatDetectionSummary,
        formatProjectMdMigrationHint,
        getCodexPromptDir,
        getToolsFromLegacyArtifacts,
        hasOpenSpecMarkers,
        isOnlyOpenSpecContent,
        legacyCleanupDeletesOnlyReleasedOutput,
        omitToolLegacyArtifacts,
        reachesWithoutLink,
        removeMarkerBlock,
    }
    src.core.config --> "test/core/legacy-cleanup.test" { OPENSPEC_MARKERS }
    "src/core/command-generation/registry" --> "test/core/legacy-cleanup.test" {
        CommandAdapterRegistry,
    }
    "src/core/command-surface" --> "test/core/legacy-cleanup.test" {
        resolveCommandSurfaceCapability,
    }
    src.core.profiles --> "test/core/legacy-cleanup.test" { ALL_WORKFLOWS }
    "test/helpers/released-codex-prompt" --> "test/core/legacy-cleanup.test" { releasedCodexPrompt }
    "src/core/legacy-cleanup" --> "test/core/legacy-cleanup.user-files.test" {
        LEGACY_SLASH_COMMAND_PATHS,
        cleanupLegacyArtifacts,
        detectLegacyArtifacts,
        formatCleanupSummary,
        formatDetectionSummary,
        getToolsFromLegacyArtifacts,
        omitToolLegacyArtifacts,
    }
    src.core.config --> "test/core/legacy-cleanup.user-files.test" { OPENSPEC_MARKERS }
    "test/helpers/run-cli" --> "test/core/legacy-cleanup.user-files.test" { runCLI }
    src.core.list --> "test/core/list.test" { ListCommand }
    "test/helpers/run-cli" --> "test/core/list.test" { runCLI }
    src.core.config --> "test/core/migration.test" { AIToolOption, AI_TOOLS }
    "src/core/command-generation/index" --> "test/core/migration.test" { CommandAdapterRegistry }
    "src/core/global-config" --> "test/core/migration.test" {
        getGlobalConfigPath,
        saveGlobalConfig,
    }
    src.core.migration --> "test/core/migration.test" {
        findLegacyToolMigrations,
        migrateIfNeeded,
        migrateLegacyToolDirs,
        scanInstalledWorkflows,
    }
    "src/utils/spec-discovery" --> "test/core/misplaced-delta-files.test" { findUnreadDeltaFiles }
    src.core.validation.validator --> "test/core/misplaced-delta-files.test" { Validator }
    src.core.archive --> "test/core/misplaced-delta-files.test" { ArchiveCommand }
    src.commands.workflow.instructions --> "test/core/misplaced-delta-files.test" {
        generateApplyInstructions,
    }
    "test/helpers/run-cli" --> "test/core/misplaced-delta-files.test" { runCLI }
    "src/core/onboarding-commands" --> "test/core/onboarding-commands.test" {
        DESCRIPTION_BUDGET,
        formatOptionalWorkflowsNote,
        getOnboardingCommands,
    }
    src.core.profiles --> "test/core/onboarding-commands.test" { ALL_WORKFLOWS, CORE_WORKFLOWS }
    src.core.openers --> "test/core/openers.test" {
        BUILTIN_OPENERS,
        buildLaunchCommand,
        findOpener,
        isOpenerCommandAvailable,
        listOpenerChoices,
        mergeOpenerTable,
    }
    src.core.index --> "test/core/openspec-root.test" {
        DEFAULT_OPENSPEC_SCHEMA,
        ensureOpenSpecRoot,
        inspectOpenSpecRoot,
        rollbackCreatedPaths,
    }
    "src/core/parsers/change-parser" --> "test/core/parsers/change-parser-delta-agreement.test" {
        ChangeParser,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/change-parser-delta-agreement.test" {
        parseDeltaSpec,
    }
    src.core.schemas.index --> "test/core/parsers/change-parser-delta-agreement.test" { Change }
    "test/helpers/run-cli" --> "test/core/parsers/change-parser-delta-agreement.test" { runCLI }
    "src/core/parsers/change-parser" --> "test/core/parsers/change-parser.test" { ChangeParser }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/closed-requirement-heading.test" {
        extractRequirementsSection,
        normalizeRequirementName,
        parseDeltaSpec,
    }
    "src/core/parsers/spec-structure" --> "test/core/parsers/closed-requirement-heading.test" {
        findMainSpecStructureIssues,
    }
    "src/core/specs-apply" --> "test/core/parsers/closed-requirement-heading.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/parsers/markdown-parser" --> "test/core/parsers/closed-section-heading.test" {
        MarkdownParser,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/closed-section-heading.test" {
        parseDeltaSpec,
    }
    "src/core/parsers/spec-structure" --> "test/core/parsers/closed-section-heading.test" {
        findMainSpecStructureIssues,
    }
    "src/core/validation/purpose-placeholder" --> "test/core/parsers/closed-section-heading.test" {
        findPurposePlaceholderIssue,
    }
    src.core.validation.validator --> "test/core/parsers/closed-section-heading.test" { Validator }
    "src/core/parsers/code-fence" --> "test/core/parsers/code-fence.test" { buildCodeFenceMask }
    "src/core/parsers/markdown-parser" --> "test/core/parsers/code-fence.test" { MarkdownParser }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/code-fence.test" {
        extractRequirementsSection,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/delta-list-markers.test" {
        parseDeltaSpec,
    }
    "src/core/specs-apply" --> "test/core/parsers/delta-list-markers.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/delta-section-collision.test" {
        parseDeltaSpec,
    }
    "src/core/specs-apply" --> "test/core/parsers/delta-section-collision.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/parsers/markdown-parser" --> "test/core/parsers/markdown-parser.test" {
        MarkdownParser,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/orphaned-requirements.test" {
        isUnrecognizedDeltaSection,
        parseDeltaSpec,
    }
    "src/core/specs-apply" --> "test/core/parsers/orphaned-requirements.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    src.core.validation.validator --> "test/core/parsers/orphaned-requirements.test" { Validator }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/renamed-pair-integrity.test" {
        parseDeltaSpec,
    }
    "src/core/specs-apply" --> "test/core/parsers/renamed-pair-integrity.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    src.core.validation.validator --> "test/core/parsers/renamed-pair-integrity.test" { Validator }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/requirement-blocks.test" {
        RequirementBlock,
        describeScenarioBalance,
        diffScenarioNames,
        extractRequirementsSection,
        findMissingCurrentScenarios,
        parseDeltaSpec,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/spec-structure-unspaced-header.test" {
        extractRequirementsSection,
    }
    "src/core/parsers/spec-structure" --> "test/core/parsers/spec-structure-unspaced-header.test" {
        findMainSpecStructureIssues,
    }
    "src/core/parsers/requirement-blocks" --> "test/core/parsers/unapplied-content.test" {
        parseDeltaSpec,
    }
    "src/core/specs-apply" --> "test/core/parsers/unapplied-content.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    src.core.validation.validator --> "test/core/parsers/unapplied-content.test" { Validator }
    "src/core/planning-home" --> "test/core/planning-home.test" {
        PlanningHome,
        formatChangeLocation,
        getChangeDir,
        resolveCurrentPlanningHomeSync,
    }
    "src/core/profile-sync-drift" --> "test/core/profile-sync-drift.test" {
        WORKFLOW_TO_SKILL_DIR,
        hasProjectConfigDrift,
        hasToolProfileOrDeliveryDrift,
    }
    src.core.profiles --> "test/core/profile-sync-drift.test" { CORE_WORKFLOWS, withRouter }
    "src/core/command-generation/index" --> "test/core/profile-sync-drift.test" {
        CommandAdapterRegistry,
        generateCommands,
    }
    src.core.shared.index --> "test/core/profile-sync-drift.test" { getCommandContents }
    src.core.profiles --> "test/core/profiles.test" {
        ALL_WORKFLOWS,
        CORE_WORKFLOWS,
        getProfileWorkflows,
        withRouter,
    }
    "src/core/project-config" --> "test/core/project-config.test" {
        OPERATION_IDS,
        loadOperationInputs,
        readProjectConfig,
        suggestSchemas,
        validateConfigRules,
    }
    "src/core/project-skills-scope" --> "test/core/project-skills-scope.test" {
        forgetProjectSkills,
        keepsProjectSkills,
        rememberProjectSkills,
    }
    "test/helpers/run-cli" --> "test/core/project-skills-vercel.test" { cliProjectRoot, runCLI }
    "src/core/validation/purpose-placeholder" --> "test/core/purpose-placeholder.test" {
        findPurposePlaceholderIssue,
    }
    src.core.validation.constants --> "test/core/purpose-placeholder.test" {
        PURPOSE_PLACEHOLDER_PREFIX,
        PURPOSE_PLACEHOLDER_SUFFIX,
    }
    src.core.references --> "test/core/references.test" {
        assembleReferenceIndex,
        escapeEnvelopeTags,
        extractFirstPurposeLine,
        renderReferencedStoresBlock,
        renderReferencedStoresSection,
    }
    src.core.store.foundation --> "test/core/references.test" {
        readStoreRegistryState,
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    "src/core/root-selection" --> "test/core/references.test" { ResolvedOpenSpecRoot }
    "test/helpers/openspec-fixtures" --> "test/core/references.test" {
        createOpenSpecRoot,
        writeSpec,
    }
    "src/core/relationship-health" --> "test/core/relationship-health.test" { inspectRelationships }
    "src/core/root-selection" --> "test/core/relationship-health.test" { ResolvedOpenSpecRoot }
    "src/core/released-output-sweep" --> "test/core/released-output-sweep.test" {
        currentGeneratablePaths,
        findStaleReleasedFiles,
        pruneEmptyParents,
    }
    "src/core/shared/released-generated-fingerprints" --> "test/core/released-output-sweep.test" {
        RELEASED_GENERATED_PATHS,
    }
    "src/core/legacy-cleanup" --> "test/core/released-output-sweep.test" {
        detectLegacyArtifacts,
        legacyCleanupDeletesOnlyReleasedOutput,
    }
    "test/helpers/run-cli" --> "test/core/released-output-sweep.test" { runCLI }
    "src/core/retired-tools" --> "test/core/retired-tools.test" {
        RetiredToolIo,
        cleanUpRetiredTools,
        findRetiredTool,
        formatRetiredToolCleanup,
        formatRetiredToolError,
    }
    src.core.config --> "test/core/retired-tools.test" { AI_TOOLS }
    "src/core/file-view" --> "test/core/retired-tools.test" { DISK_VIEW }
    "src/core/root-selection" --> "test/core/root-selection.test" {
        RootSelectionError,
        resolveOpenSpecRoot,
    }
    src.core.store.foundation --> "test/core/root-selection.test";
    src.core.store.foundation --> "test/core/root-selection.test" {
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    "src/core/global-config" --> "test/core/root-selection.test" { saveGlobalConfig }
    src.core.store.git --> "test/core/root-selection.test" { envWithoutGitRepoLocation }
    "test/helpers/fake-tool" --> "test/core/root-selection.test" { createFakeTool }
    "test/helpers/path-env" --> "test/core/root-selection.test" { withPrependedPathEnv }
    "src/core/templates/workflows/project-root" --> "test/core/root-selection.test";
    "test/helpers/run-cli" --> "test/core/router-skill.test" { cliProjectRoot, runCLI }
    "src/core/shared/ide-restart" --> "test/core/shared-ide-restart.test" {
        formatIdeRestart,
        resolveIdeRestartSurface,
    }
    src.core.config --> "test/core/shared-skill-target.test" { AI_TOOLS }
    "src/core/shared-skill-target" --> "test/core/shared-skill-target.test" {
        formatSkillToolList,
        hasOwnFolderSkills,
        isToolListed,
        readSkillToolList,
        skillToolListPath,
    }
    "src/core/file-view" --> "test/core/shared-skill-target.test" { FileView }
    "src/core/shared/tool-detection" --> "test/core/shared/generated-by-scan.security.test" {
        extractGeneratedByVersion,
    }
    "src/core/shared/skill-content-equivalence" --> "test/core/shared/generated-by-scan.security.test" {
        isLegacyCodexSkillEquivalentToCurrent,
    }
    "src/core/shared/generated-fingerprint" --> "test/core/shared/generated-fingerprint.test" {
        fingerprintGeneratedContent,
        isReleasedGeneratedContent,
    }
    "src/core/shared/released-generated-fingerprints" --> "test/core/shared/generated-fingerprint.test" {
        RELEASED_GENERATED_FINGERPRINTS,
    }
    "src/core/shared/skill-content-equivalence" --> "test/core/shared/generated-fingerprint.test" {
        isRedundantLegacyCopy,
    }
    "src/core/shared/skill-generation" --> "test/core/shared/profile-workflow-references.test" {
        getCommandContents,
        getSkillTemplates,
    }
    src.core.profiles --> "test/core/shared/profile-workflow-references.test" {
        ALL_WORKFLOWS,
        CORE_WORKFLOWS,
        getProfileWorkflows,
    }
    "src/core/shared/skill-content-equivalence" --> "test/core/shared/skill-content-equivalence.test" {
        isLegacyCodexSkillEquivalentToCurrent,
    }
    "src/core/shared/skill-generation" --> "test/core/shared/skill-generation.test" {
        generateSkillContent,
        generateSkillFiles,
        getCommandContents,
        getCommandTemplates,
        getSkillTemplates,
    }
    "src/core/shared/skill-links" --> "test/core/shared/skill-links.test" {
        classifySkillLinkSpot,
        createSkillLink,
    }
    src.core.config --> "test/core/shared/skill-links.test" { AI_TOOLS, installerAgent }
    "src/core/shared/skill-paths" --> "test/core/shared/skill-links.test" {
        resolveFormerOwnSkillsDir,
        resolveSharedSkillsDir,
        resolveSkillLinkDir,
        usesSharedSkills,
    }
    src.core.config --> "test/core/shared/skill-paths.test" { AI_TOOLS }
    "src/core/shared/skill-paths" --> "test/core/shared/skill-paths.test" {
        getSkillCapableTools,
        resolveToolSkillsDir,
        toolSupportsSkills,
    }
    "src/core/shared/tool-detection" --> "test/core/shared/tool-detection.test" {
        SKILL_NAMES,
        extractGeneratedByVersion,
        getAllToolVersionStatus,
        getConfiguredTools,
        getToolSkillStatus,
        getToolStates,
        getToolVersionStatus,
        getToolsWithSkillsDir,
    }
    src.core.init --> "test/core/shared/tool-detection.test";
    "src/core/global-config" --> "test/core/shared/tool-detection.test";
    "src/core/command-generation/index" --> "test/core/shared/tool-detection.test";
    "src/core/shared/skill-generation" --> "test/core/shared/tool-detection.test";
    src.core.init --> "test/core/skills-2-0-hardening.test" { InitCommand }
    src.core.update --> "test/core/skills-2-0-hardening.test" { UpdateCommand }
    "src/core/shared/skill-links" --> "test/core/skills-2-0-hardening.test" {
        classifySkillLinkSpot,
        createSkillLink,
        skillLinkText,
    }
    "src/core/shared/tool-detection" --> "test/core/skills-2-0-hardening.test" {
        getConfiguredTools,
    }
    "src/core/legacy-cleanup" --> "test/core/skills-2-0-hardening.test" { detectLegacyArtifacts }
    "src/core/profile-sync-drift" --> "test/core/skills-2-0-hardening.test" {
        hasProjectConfigDrift,
    }
    src.core.profiles --> "test/core/skills-2-0-hardening.test" { CORE_WORKFLOWS }
    "test/helpers/released-codex-prompt" --> "test/core/skills-2-0-hardening.test" {
        releasedCodexPrompt,
    }
    src.commands.config --> "test/core/skills-2-0-hardening.test";
    "src/core/specs-apply" --> "test/core/specs-apply.comment-masking.security.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.fence-preservation.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.line-endings.test" {
        buildUpdatedSpec,
        findSpecUpdates,
        writeUpdatedSpec,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.project-linked-spec.test" {
        buildUpdatedSpec,
        findSpecUpdates,
        writeUpdatedSpec,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.requirement-name-near-miss.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.salvage.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.security.test" {
        buildUpdatedSpec,
        findSpecUpdates,
        writeUpdatedSpec,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.serialization.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/specs-apply" --> "test/core/specs-apply.symlink-escape.security.test" {
        findSpecUpdates,
    }
    "src/core/standalone-tip" --> "test/core/standalone-tip.test";
    "src/core/global-config" --> "test/core/store/foundation.test" { getGlobalDataDir }
    src.core.store.index --> "test/core/store/foundation.test" {
        STORES_DIR_NAME,
        STORE_METADATA_DIR_NAME,
        STORE_METADATA_FILE_NAME,
        STORE_REGISTRY_FILE_NAME,
        getStoreMetadataDir,
        getStoreMetadataPath,
        getStoreRegistryPath,
        getStoresDir,
        isStoreRoot,
        isValidStoreId,
        listStoreRegistryEntries,
        parseStoreMetadataState,
        parseStoreRegistryState,
        readOptionalStoreMetadataState,
        readStoreMetadataState,
        readStoreRegistryState,
        resolveGitStoreBackendConfig,
        serializeStoreMetadataState,
        serializeStoreRegistryState,
        validateStoreId,
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    src.core.store.git --> "test/core/store/git-probe-limits.test" {
        GIT_EXEC_OPTIONS,
        GIT_WRITE_EXEC_OPTIONS,
        gitHasUncommittedChanges,
        isProbeResourceFailure,
    }
    src.core.store.git --> "test/core/store/git-repo-name.test" { repoNameFromGitUrl }
    src.core.id --> "test/core/store/git-repo-name.test" { isKebabId, toKebabCase }
    src.core.index --> "test/core/store/registry.test" {
        getGlobalDataDir,
        getStoreMetadataPath,
        listRegisteredStores,
        prepareStoreCleanup,
        prepareStoreSetup,
        readStoreMetadataState,
        readStoreRegistryState,
        registerStore,
        removeStore,
        resolveRegisteredStore,
        setupPreparedStore,
        setupStore,
        unregisterStoreRegistration,
        writeStoreMetadataState,
        writeStoreRegistryState,
    }
    "src/core/validation/task-checkboxes" --> "test/core/task-checkboxes.test" {
        findMissingTaskCheckboxIssues,
    }
    "src/core/validation/task-numbering" --> "test/core/task-numbering.test" {
        findTaskNumberingIssues,
    }
    "src/core/templates/workflows/apply-change" --> "test/core/templates/apply-defer-guardrail.test" {
        getApplyChangeSkillTemplate,
        getApplyInstructions,
        getOpsxApplyCommandTemplate,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/archive-existing-target.test" {
        getArchiveChangeSkillTemplate,
        getOpsxArchiveCommandTemplate,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/archive-task-progress.test" {
        generateSkillContent,
        getCommandTemplates,
        getSkillTemplates,
    }
    src.core.index --> "test/core/templates/archive-task-progress.test" {
        getGlobalDataDir,
        registerStore,
    }
    "test/helpers/run-cli" --> "test/core/templates/archive-task-progress.test" { runCLI }
    "src/core/templates/skill-templates" --> "test/core/templates/bulk-archive-existing-target.test" {
        getBulkArchiveChangeSkillTemplate,
        getOpsxBulkArchiveCommandTemplate,
    }
    "src/utils/command-references" --> "test/core/templates/explore.test" {
        getSkillReferenceTransformer,
        transformCommandInvocations,
        transformToCodexCompatibleSkillReferences,
        transformToSkillReferences,
    }
    "src/core/command-generation/registry" --> "test/core/templates/explore.test" {
        CommandAdapterRegistry,
    }
    "src/core/command-generation/invocation" --> "test/core/templates/explore.test" {
        formatCommandInvocation,
        getInvocationForAdapter,
    }
    src.core.config --> "test/core/templates/explore.test" { AI_TOOLS }
    "src/core/shared/skill-generation" --> "test/core/templates/explore.test" {
        generateSkillContent,
        getCommandContents,
        getCommandTemplates,
        getSkillTemplates,
    }
    "src/core/command-generation/generator" --> "test/core/templates/explore.test" {
        generateCommands,
    }
    src.core.profiles --> "test/core/templates/explore.test" { getProfileWorkflows }
    "src/core/templates/skill-templates" --> "test/core/templates/glob-path-bounding.test" {
        getContinueChangeSkillTemplate,
        getExploreSkillTemplate,
        getFfChangeSkillTemplate,
        getOpsxContinueCommandTemplate,
        getOpsxExploreCommandTemplate,
        getOpsxFfCommandTemplate,
        getOpsxProposeCommandTemplate,
        getOpsxProposeSkillTemplate,
        getOpsxUpdateCommandTemplate,
        getUpdateChangeSkillTemplate,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/list-json-contract.test" {
        getBulkArchiveChangeSkillTemplate,
        getContinueChangeSkillTemplate,
        getExploreSkillTemplate,
        getOpsxBulkArchiveCommandTemplate,
        getOpsxContinueCommandTemplate,
        getOpsxExploreCommandTemplate,
        getOpsxUpdateCommandTemplate,
        getUpdateChangeSkillTemplate,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/list-json-contract.test" {
        getCommandTemplates,
        getSkillTemplates,
    }
    "src/core/artifact-graph/schema" --> "test/core/templates/main-spec-paths.test" { loadSchema }
    "src/core/planning-home" --> "test/core/templates/main-spec-paths.test" {
        resolveCurrentPlanningHomeSync,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/one-text-per-skill.test" {
        generateSkillContent,
        getCommandContents,
        getSkillTemplates,
    }
    src.core.profiles --> "test/core/templates/one-text-per-skill.test" {
        ALL_WORKFLOWS,
        SKILL_WORKFLOWS,
    }
    "scripts/parity-hash-shared" --> "test/core/templates/parity-hash-shared.test" {
        rewriteParityHashes,
    }
    "src/core/templates/workflows/project-root" --> "test/core/templates/project-root-guard.test" {
        PROJECT_ROOT_GUARD,
    }
    "src/core/templates/workflows/store-selection" --> "test/core/templates/project-root-guard.test" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/project-root-guard.test" {
        getFeedbackSkillTemplate,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/project-root-guard.test" {
        generateSkillContent,
        getCommandContents,
        getSkillTemplates,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/propose.test" {
        getFfChangeSkillTemplate,
        getOpsxFfCommandTemplate,
        getOpsxProposeCommandTemplate,
        getOpsxProposeSkillTemplate,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/propose.test" {
        generateSkillContent,
        getCommandContents,
    }
    "src/core/artifact-graph/schema" --> "test/core/templates/propose.test" { loadSchema }
    "src/core/command-generation/registry" --> "test/core/templates/propose.test" {
        CommandAdapterRegistry,
    }
    "src/core/command-generation/generator" --> "test/core/templates/propose.test" {
        generateCommand,
    }
    "src/core/command-generation/invocation" --> "test/core/templates/propose.test" {
        formatCommandInvocation,
        getInvocationForAdapter,
    }
    "src/core/project-config" --> "test/core/templates/propose.test" { MAX_CONTEXT_SIZE }
    src.core.profiles --> "test/core/templates/propose.test" { ALL_WORKFLOWS }
    "src/utils/task-progress" --> "test/core/templates/propose.test" { parseTaskLines }
    "src/core/artifact-graph/schema" --> "test/core/templates/requirement-length-guidance.test" {
        parseSchema,
    }
    src.core.validation.constants --> "test/core/templates/requirement-length-guidance.test" {
        MAX_REQUIREMENT_TEXT_LENGTH,
    }
    "src/core/artifact-graph/schema" --> "test/core/templates/schema-docs-instruction-parity.test" {
        parseSchema,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/skill-templates-parity.test" {
        SkillTemplate,
        getApplyChangeSkillTemplate,
        getApplyInstructions,
        getArchiveChangeSkillTemplate,
        getBulkArchiveChangeSkillTemplate,
        getContinueChangeSkillTemplate,
        getExploreSkillTemplate,
        getFeedbackSkillTemplate,
        getFfChangeSkillTemplate,
        getNewChangeSkillTemplate,
        getOnboardSkillTemplate,
        getOpsxApplyCommandTemplate,
        getOpsxArchiveCommandTemplate,
        getOpsxBulkArchiveCommandTemplate,
        getOpsxContinueCommandTemplate,
        getOpsxExploreCommandTemplate,
        getOpsxFfCommandTemplate,
        getOpsxNewCommandTemplate,
        getOpsxOnboardCommandTemplate,
        getOpsxProposeCommandTemplate,
        getOpsxProposeSkillTemplate,
        getOpsxSyncCommandTemplate,
        getOpsxUpdateCommandTemplate,
        getOpsxVerifyCommandTemplate,
        getRouterSkillTemplate,
        getSyncSpecsSkillTemplate,
        getUpdateChangeSkillTemplate,
        getVerifyChangeSkillTemplate,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/skill-templates-parity.test" {
        generateSkillContent,
        generateSkillFiles,
        getCommandContents,
        getSkillTemplates,
    }
    "src/core/templates/workflows/store-selection" --> "test/core/templates/skill-templates-parity.test" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/artifact-graph/schema" --> "test/core/templates/skill-templates-parity.test" {
        parseSchema,
    }
    "scripts/skillssh-shared" --> "test/core/templates/skillssh-generator-guards.test" {
        cleanSkillSubdirectories,
        prepareSkillDirectory,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/skillssh-parity.test" {
        generateSkillFiles,
        getSkillTemplates,
    }
    "src/utils/command-references" --> "test/core/templates/skillssh-parity.test" {
        transformToSharedSkillReferences,
    }
    "scripts/skillssh-shared" --> "test/core/templates/skillssh-parity.test" {
        SKILLS_DIR,
        stripVolatileFrontmatter,
    }
    "src/core/shared/skill-generation" --> "test/core/templates/spec-inventory.test" {
        getCommandTemplates,
        getSkillTemplates,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/spec-inventory.test" {
        getExploreSkillTemplate,
        getOpsxExploreCommandTemplate,
    }
    "src/core/artifact-graph/schema" --> "test/core/templates/spec-inventory.test" { loadSchema }
    "src/core/templates/skill-templates" --> "test/core/templates/update-change.test" {
        getOpsxUpdateCommandTemplate,
        getUpdateChangeSkillTemplate,
    }
    "src/core/templates/workflows/store-selection" --> "test/core/templates/update-change.test" {
        STORE_SELECTION_GUIDANCE,
    }
    "src/core/templates/workflows/project-root" --> "test/core/templates/update-change.test" {
        PROJECT_ROOT_GUARD,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/verify-change-delta-operations.test" {
        getOpsxVerifyCommandTemplate,
        getVerifyChangeSkillTemplate,
    }
    "src/core/templates/skill-templates" --> "test/core/templates/verify-change.test" {
        getOpsxVerifyCommandTemplate,
        getVerifyChangeSkillTemplate,
    }
    src.cli.index --> "test/core/templates/workflow-verb-triggers.test" { program }
    src.core.profiles --> "test/core/templates/workflow-verb-triggers.test" { ALL_WORKFLOWS }
    "src/core/shared/skill-generation" --> "test/core/templates/workflow-verb-triggers.test" {
        generateSkillContent,
        getSkillTemplates,
    }
    src.core.config --> "test/core/tool-search-aliases.test" {
        AI_TOOLS,
        getUniversalTool,
        universalToolFallbackHint,
    }
    src.core.init --> "test/core/update-dry-run.property.test" { InitCommand }
    src.core.update --> "test/core/update-dry-run.property.test" { UpdateCommand }
    "src/core/global-config" --> "test/core/update-dry-run.property.test" { getGlobalConfigPath }
    "src/core/github-copilot/cloud-agent" --> "test/core/update-dry-run.property.test" {
        generateCopilotSetupSteps,
        persistCopilotCloudOptIn,
    }
    src.core.update --> "test/core/update-dry-run.test" { UpdateCommand }
    src.core.init --> "test/core/update-dry-run.test" { InitCommand }
    src.core.profiles --> "test/core/update-dry-run.test" { ALL_WORKFLOWS }
    "src/core/global-config" --> "test/core/update-dry-run.test" {
        GlobalConfig,
        getGlobalConfigPath,
    }
    "src/core/update-plan" --> "test/core/update-dry-run.test" { UpdatePlanChange }
    "src/core/command-generation/index" --> "test/core/update-dry-run.test" {
        CommandAdapterRegistry,
        generateCommands,
    }
    "src/core/shared/skill-generation" --> "test/core/update-dry-run.test" { getCommandContents }
    "src/core/github-copilot/cloud-agent" --> "test/core/update-dry-run.test" {
        generateCopilotSetupSteps,
        persistCopilotCloudOptIn,
    }
    "test/helpers/released-codex-prompt" --> "test/core/update-dry-run.test" { releasedCodexPrompt }
    src.core.update --> "test/core/update-skill-tamper.test" { UpdateCommand }
    src.core.init --> "test/core/update-skill-tamper.test" { InitCommand }
    "src/core/global-config" --> "test/core/update-skill-tamper.test" { GlobalConfig }
    "src/core/global-skills" --> "test/core/update.test";
    "src/core/skill-installer" --> "test/core/update.test";
    src.core.update --> "test/core/update.test" { UpdateCommand, scanInstalledWorkflows }
    src.core.init --> "test/core/update.test" { InitCommand }
    "src/core/project-skills-scope" --> "test/core/update.test" { rememberProjectSkills }
    "src/core/profile-sync-drift" --> "test/core/update.test" { getConfiguredToolsForProfileSync }
    src.core.profiles --> "test/core/update.test" { ALL_WORKFLOWS }
    "src/utils/file-system" --> "test/core/update.test" { FileSystemUtils }
    src.core.config --> "test/core/update.test";
    src.core.config --> "test/core/update.test" { OPENSPEC_MARKERS }
    "src/core/global-config" --> "test/core/update.test" { GlobalConfig }
    "src/core/github-copilot/cloud-agent" --> "test/core/update.test" {
        generateCopilotSetupSteps,
        persistCopilotCloudOptIn,
    }
    src.core.shared.index --> "test/core/update.test" { getCommandContents }
    "src/core/command-generation/index" --> "test/core/update.test" {
        CommandAdapterRegistry,
        generateCommands,
    }
    "test/helpers/released-codex-prompt" --> "test/core/update.test" { releasedCodexPrompt }
    "test/helpers/store-git" --> "test/core/update.test" { isolatedGitEnv }
    "src/core/command-surface" --> "test/core/update.test";
    src.core.validation.validator --> "test/core/validation.archive-preflight.test" { Validator }
    "src/core/specs-apply" --> "test/core/validation.archive-preflight.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    src.core.validation.validator --> "test/core/validation.enriched-messages.test" { Validator }
    src.core.validation.validator --> "test/core/validation.purpose-placeholder.test" { Validator }
    src.core.validation.constants --> "test/core/validation.purpose-placeholder.test" {
        MIN_PURPOSE_LENGTH,
        PURPOSE_PLACEHOLDER_PREFIX,
        PURPOSE_PLACEHOLDER_SUFFIX,
        VALIDATION_MESSAGES,
    }
    "src/core/parsers/requirement-text" --> "test/core/validation.scenario-body-parity.test" {
        countScenarios,
    }
    "src/core/parsers/markdown-parser" --> "test/core/validation.scenario-body-parity.test" {
        MarkdownParser,
    }
    src.core.validation.validator --> "test/core/validation.scenario-body-parity.test" { Validator }
    "test/helpers/run-cli" --> "test/core/validation.scenario-body-parity.test" { runCLI }
    src.core.validation.validator --> "test/core/validation.scenario-loss.test" { Validator }
    "src/core/specs-apply" --> "test/core/validation.scenario-loss.test" {
        buildUpdatedSpec,
        findSpecUpdates,
    }
    "src/core/parsers/requirement-text" --> "test/core/validation.scenario-steps.test" {
        scenarioStepCoverage,
    }
    src.core.validation.validator --> "test/core/validation.scenario-steps.test" { Validator }
    "test/helpers/run-cli" --> "test/core/validation.scenario-steps.test" { runCLI }
    src.core.validation.validator --> "test/core/validation.skip-specs.test" { Validator }
    src.core.validation.validator --> "test/core/validation.test" { Validator }
    src.core.validation.constants --> "test/core/validation.test" {
        MAX_REQUIREMENT_TEXT_LENGTH,
        VALIDATION_MESSAGES,
    }
    src.core.schemas.index --> "test/core/validation.test" {
        ChangeSchema,
        DeltaSchema,
        RequirementSchema,
        ScenarioSchema,
        SpecSchema,
    }
    src.core.validation.validator --> "test/core/validation.unknown-metadata-keys.test" {
        Validator,
    }
    "src/core/artifact-graph/instruction-loader" --> "test/core/validation.unknown-metadata-keys.test" {
        loadChangeContext,
    }
    "src/utils/change-metadata" --> "test/core/validation.unknown-metadata-keys.test" {
        METADATA_FILENAME,
    }
    "src/core/change-metadata/schema" --> "test/core/validation.unknown-metadata-keys.test" {
        CHANGE_METADATA_KNOWN_KEYS,
        ChangeMetadataSchema,
    }
    "src/core/version-check" --> "test/core/version-check.test";
    "src/core/version-check" --> "test/core/version-check.test" {
        buildCliUpdateLines,
        buildUpgradeCommandLines,
        buildVersionReportLines,
        canSelfUpgrade,
        checkForCliUpdate,
        compareVersions,
        detectPackageManager,
        displayCliUpdateNote,
        getAvailableCliUpdate,
        getCliInstallInfo,
        getCliUpdateCommand,
        getInstallDir,
        isEphemeralRunnerInstall,
        isNpmGlobalInstall,
        isProjectLocalInstall,
        isSourceCheckout,
        npmGlobalRoots,
        npmPrefixFromInstallDir,
        offerCliUpgrade,
        readCliVersion,
        registryUrl,
        rerunUpdateWithUpgradedCli,
        shouldOfferUpgrade,
        upgradedBinPath,
    }
    src.core.view --> "test/core/view.test" { ViewCommand }
    src.core.init --> "test/core/warp.test" { InitCommand }
    src.core.update --> "test/core/warp.test" { UpdateCommand }
    src.core.config --> "test/core/warp.test" { AI_TOOLS }
    "src/core/available-tools" --> "test/core/warp.test" { getAvailableTools }
    "src/core/command-surface" --> "test/core/warp.test" { resolveCommandSurfaceCapability }
    "src/core/command-generation/registry" --> "test/core/warp.test" { CommandAdapterRegistry }
    "src/core/global-config" --> "test/core/warp.test" { GlobalConfig }
    "src/core/legacy-cleanup" --> "test/core/warp.test" { LEGACY_GLOBAL_SLASH_COMMAND_PATHS }
    src.core.profiles --> "test/core/warp.test" { ALL_WORKFLOWS, CORE_WORKFLOWS, withRouter }
    "src/core/shared/skill-generation" --> "test/core/warp.test" { getSkillTemplates }
    "src/core/shared/tool-detection" --> "test/core/warp.test" {
        getConfiguredTools,
        getToolSkillStatus,
    }
    "src/core/working-set" --> "test/core/working-set.test" {
        assembleWorkingSet,
        buildCodeWorkspaceJson,
        isAvailableMember,
    }
    "src/core/root-selection" --> "test/core/working-set.test" { ResolvedOpenSpecRoot }
    src.core.store.errors --> "test/core/working-set.test" { StoreDiagnostic }
    src.core.worksets --> "test/core/worksets.test" {
        WORKSETS_DIR_NAME,
        WORKSETS_FILE_NAME,
        WorksetsState,
        buildWorksetCodeWorkspaceJson,
        getWorkset,
        getWorksetCodeWorkspacePath,
        getWorksetsDir,
        getWorksetsFilePath,
        listWorksets,
        memberLabelProblem,
        memberListProblem,
        parseWorksetsState,
        readWorksetsState,
        serializeWorksetsState,
        updateWorksetsState,
        validateWorksetName,
        withWorkset,
        withWorksetsLock,
        withoutWorkset,
    }
    "test/helpers/fake-tool" --> "test/package-install-scripts.test" {
        createFakeTool,
        envWithFakeTools,
    }
    "test/helpers/store-git" --> "test/package-install-scripts.test" { isolatedGitEnv }
    "src/prompts/searchable-multi-select" --> "test/prompts/searchable-multi-select.test";
    "src/core/command-generation/adapters/claude" --> "test/setup-docs-claims.test" {
        claudeAdapter,
    }
    src.core.config --> "test/setup-docs-claims.test" { AI_TOOLS, SKILL_LINKED_TOOL_IDS }
    "src/core/shared/skill-paths" --> "test/setup-docs-claims.test" { SHARED_SKILLS_ROOT }
    "src/core/legacy-cleanup" --> "test/setup-docs-claims.test" { formatProjectMdMigrationHint }
    src.core.profiles --> "test/setup-docs-claims.test" { CORE_WORKFLOWS }
    "src/core/parsers/markdown-parser" --> "test/specs/source-specs-normalization.test" {
        MarkdownParser,
    }
    "src/core/parsers/spec-structure" --> "test/specs/source-specs-normalization.test" {
        findMainSpecStructureIssues,
        stripFencedCodeBlocksPreservingLines,
    }
    src.telemetry.config --> "test/telemetry/config.test" {
        getConfigPath,
        getTelemetryConfig,
        readConfig,
        updateTelemetryConfig,
        writeConfig,
    }
    src.telemetry.index --> "test/telemetry/index.test" {
        isTelemetryEnabled,
        maybeShowTelemetryNotice,
        shutdown,
        trackCommand,
    }
    src.telemetry.config --> "test/telemetry/index.test" { getTelemetryConfig }
    src.core.profiles --> "test/ui/welcome-screen.test" { ALL_WORKFLOWS, CORE_WORKFLOWS }
    "src/ui/welcome-screen" --> "test/ui/welcome-screen.test";
    "src/core/profile-sync-drift" --> "test/upgrade-to-2-docs-claims.test" { WORKFLOW_TO_SKILL_DIR }
    src.commands.config --> "test/upgrade-to-2-docs-claims.test" { DELIVERY_RETIRED_NOTE }
    src.core.profiles --> "test/upgrade-to-2-docs-claims.test" { ALL_WORKFLOWS }
    "src/utils/change-metadata" --> "test/utils/change-metadata.test" {
        ChangeMetadataError,
        formatUnknownChangeMetadataKeysMessage,
        isExtensionMetadataKey,
        listUnknownChangeMetadataKeys,
        readChangeMetadata,
        readRetireCapabilitiesMarker,
        resolveSchemaForChange,
        validateSchemaName,
        writeChangeMetadata,
    }
    "src/core/change-metadata/index" --> "test/utils/change-metadata.test" { ChangeMetadataSchema }
    "src/utils/change-utils" --> "test/utils/change-utils.test" { createChange, validateChangeName }
    src.utils.ci --> "test/utils/ci.test" { isCiEnvironment }
    "src/utils/command-references" --> "test/utils/command-references.test" {
        getSkillReferenceTransformer,
        getTransformerForTool,
        transformCommandInvocations,
        transformToSkillReferences,
    }
    "src/core/command-generation/invocation" --> "test/utils/command-references.test" {
        CommandInvocation,
    }
    "src/core/templates/workflows/apply-change" --> "test/utils/command-references.test" {
        getApplyChangeSkillTemplate,
    }
    "src/utils/file-system" --> "test/utils/file-system.test" { FileSystemUtils }
    src.utils.interactive --> "test/utils/interactive.test" {
        InteractiveOptions,
        canRenderSpinner,
        confirmPrompt,
        isInteractive,
        isNonInteractivePromptError,
        resolveNoInteractive,
    }
    "src/utils/item-discovery" --> "test/utils/item-discovery.test" {
        getActiveChangeIds,
        getArchivedChangeIds,
    }
    "src/utils/line-endings" --> "test/utils/line-endings.test" {
        applyLineEnding,
        detectLineEnding,
        matchLineEnding,
    }
    "src/utils/file-system" --> "test/utils/marker-updates.test" {
        FileSystemUtils,
        removeMarkerBlock,
    }
    "src/utils/nested-change" --> "test/utils/nested-change.test" {
        describeNestedChange,
        findNestedChanges,
        findNestedChangesIn,
    }
    "src/utils/file-system" --> "test/utils/path-containment.test" { FileSystemUtils }
    "src/utils/requirement-diff" --> "test/utils/requirement-diff.test" {
        buildRenameMap,
        diffRequirementBlock,
        extractRequirementBlock,
    }
    "src/utils/shell-detection" --> "test/utils/shell-detection.test" {
        SupportedShell,
        detectShell,
    }
    "src/utils/spec-discovery" --> "test/utils/spec-discovery.test" { discoverSpecFiles }
    "src/utils/spec-path-containment" --> "test/utils/spec-path-containment.test" {
        assertDiscoveredSpecFile,
        assertSpecFileWithin,
    }
    "src/utils/task-progress" --> "test/utils/task-progress.list-markers.test" {
        countTasksFromContent,
        parseTaskLines,
    }
    "src/core/validation/task-numbering" --> "test/utils/task-progress.list-markers.test" {
        findTaskNumberingIssues,
    }
    "test/helpers/run-cli" --> "test/utils/task-progress.list-markers.test" { runCLI }
    "src/utils/task-progress" --> "test/utils/task-progress.test" {
        countTasksFromContent,
        formatTaskStatus,
        getTaskProgressDetailForChange,
        getTaskProgressForChange,
        parseTaskLines,
    }
    "src/core/artifact-graph/index" --> "test/utils/task-progress.test" { resolveArtifactOutputs }
    website.scripts.preview --> "test/website-preview.test";
    "test/helpers/run-cli" --> "vitest.setup" { ensureCliBuilt, terminateActiveCliChildren }
    "scripts/skillssh-shared" --> "scripts/generate-skillssh" {
        SKILLS_DIR,
        cleanSkillSubdirectories,
        prepareSkillDirectory,
        stripVolatileFrontmatter,
    }
    "scripts/parity-hash-shared" --> "scripts/regen-parity-hashes" {
        rewriteParityHashes,
        stableStringify,
    }
    src.cli.index --> src.index;
    src.core.index --> src.index;
    "dist/core/shared/skill-generation.d" --> "scripts/skillssh-shared" { stripVolatileFrontmatter }
    "dist/core/templates/skill-templates.d" --> "dist/core/shared/skill-generation.d" {
        SkillTemplate,
        getOpsxExploreCommandTemplate,
    }
    "dist/core/command-generation/index.d" --> "dist/core/shared/skill-generation.d" {
        CommandContent,
    }
    "dist/core/templates/workflows/explore.d" --> "dist/core/templates/skill-templates.d" {
        getExploreSkillTemplate,
        getOpsxExploreCommandTemplate,
    }
    "dist/core/templates/workflows/new-change.d" --> "dist/core/templates/skill-templates.d" {
        getNewChangeSkillTemplate,
        getOpsxNewCommandTemplate,
    }
    "dist/core/templates/workflows/continue-change.d" --> "dist/core/templates/skill-templates.d" {
        getContinueChangeSkillTemplate,
        getOpsxContinueCommandTemplate,
    }
    "dist/core/templates/workflows/apply-change.d" --> "dist/core/templates/skill-templates.d" {
        getApplyChangeSkillTemplate,
        getApplyInstructions,
        getOpsxApplyCommandTemplate,
    }
    "dist/core/templates/workflows/update-change.d" --> "dist/core/templates/skill-templates.d" {
        getOpsxUpdateCommandTemplate,
        getUpdateChangeSkillTemplate,
    }
    "dist/core/templates/workflows/ff-change.d" --> "dist/core/templates/skill-templates.d" {
        getFfChangeSkillTemplate,
        getOpsxFfCommandTemplate,
    }
    "dist/core/templates/workflows/sync-specs.d" --> "dist/core/templates/skill-templates.d" {
        getOpsxSyncCommandTemplate,
        getSyncSpecsSkillTemplate,
    }
    "dist/core/templates/workflows/archive-change.d" --> "dist/core/templates/skill-templates.d" {
        getArchiveChangeSkillTemplate,
        getOpsxArchiveCommandTemplate,
    }
    "dist/core/templates/workflows/bulk-archive-change.d" --> "dist/core/templates/skill-templates.d" {
        getBulkArchiveChangeSkillTemplate,
        getOpsxBulkArchiveCommandTemplate,
    }
    "dist/core/templates/workflows/verify-change.d" --> "dist/core/templates/skill-templates.d" {
        getOpsxVerifyCommandTemplate,
        getVerifyChangeSkillTemplate,
    }
    "dist/core/templates/workflows/onboard.d" --> "dist/core/templates/skill-templates.d" {
        getOnboardSkillTemplate,
        getOpsxOnboardCommandTemplate,
    }
    "dist/core/templates/workflows/propose.d" --> "dist/core/templates/skill-templates.d" {
        getOpsxProposeCommandTemplate,
        getOpsxProposeSkillTemplate,
    }
    "dist/core/command-generation/registry.d" --> "dist/core/command-generation/index.d" {
        CommandAdapterRegistry,
    }
    "dist/core/command-generation/generator.d" --> "dist/core/command-generation/index.d" {
        generateCommand,
        generateCommands,
    }
    "dist/core/command-generation/adapters/index.d" --> "dist/core/command-generation/index.d" {
        claudeAdapter,
        cursorAdapter,
        devinAdapter,
    }
    "dist/core/command-generation/adapters/claude.d" --> "dist/core/command-generation/adapters/index.d" {
        claudeAdapter,
    }
    "dist/cli/index.d" --> bin.openspec { runCli }
    "dist/core/artifact-graph/resolver.d" --> scripts.binary.entry { setPackageSchemasDir }
    "dist/core/version-check.d" --> scripts.binary.entry { markStandaloneBinary }
    "dist/cli/index.d" --> scripts.binary.entry;
    "dist/core/shared/skill-generation.d" --> "scripts/generate-skillssh" {
        generateSkillFiles,
        getSkillTemplates,
    }
    "dist/utils/command-references.d" --> "scripts/generate-skillssh" {
        transformToSharedSkillReferences,
    }
    "dist/core/command-surface.d" --> "dist/utils/command-references.d" { CommandSurfaceCapability }
}
