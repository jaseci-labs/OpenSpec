# Contributing

Thanks for helping improve OpenSpec.

Every contribution starts with a GitHub issue. We discuss the problem there, and if we agree to pursue it, a maintainer implements the change or invites you to build it with us. Pull requests come from maintainers and invited contributors. [An Update to OpenSpec's Contribution Policy](https://openspec.dev/blog/openspec-contribution-policy/) explains why.

## 1. Open an issue

[Pick a form](https://github.com/Fission-AI/OpenSpec/issues/new/choose): bug, feature, or docs.

- **Bug:** what you were trying to do, what happened, what you expected, and the shortest steps that reproduce it from a fresh project. Error messages, logs, and a minimal example help most. We can't fix what we can't reproduce.
- **Agent behavior:** say which agent and model you used, and attach a session trace if you have one. Which files the agent read, which tools it called, and whether the behavior repeats across sessions is usually what narrows it down.
- **Feature:** describe the problem, who else it affects, what you tried instead, and whether the added complexity is worth maintaining. You don't need a solution; sometimes the behavior you hit is a deliberate trade-off, and that is what we want to talk about.

From a project you're working in, `openspec feedback "what happened"` files a bug for you with your version and platform filled in, or hands you a prefilled form link.

If an agent drafts the issue, read it through and make it yours. We don't expect you to have all the answers, but we do want the issue to show that you have considered the problem.

## 2. We discuss it on the issue

We work out the problem, the possible approaches, and whether it fits OpenSpec's priorities. OpenSpec runs across many agents, models, and workflows, so a change that helps one workflow can break another.

If we agree to pursue it, a maintainer adds the `approved` label and then either implements it or invites you to build it with us. Say on the issue if you would like to write the fix. We can't promise to take on every suggestion.

Opening pull requests is limited to maintainers, so wait for an invitation on the issue before you start one.

## 3. Open the PR (invited contributors and maintainers)

**Bug or docs:** one PR with the fix. Write `Closes #123` in the description. It shouldn't change `openspec/`, since specs are for features.

**Feature:** two PRs, once we've agreed on the change in the issue.

1. **Proposal:** only `openspec/changes/<name>/`. Write `Part of #123`, so the issue stays open.
2. **Implementation:** after the proposal merges, the code plus updates to that change, such as checking off its `tasks.md`. Write `Closes #123`.

## Development setup

OpenSpec's source is [Jac](https://github.com/jaseci-labs/neojac), compiled to JavaScript by the `neojac` toolchain (Linux and macOS; it carries its own Node). The published package and the standalone binaries are plain JavaScript and run anywhere Node 22.20.0+ does.

```bash
curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash -s -- --version 0.5.1
neojac install          # npm packages, from jac.toml; writes package.json
neojac check            # types, imports and lint of every Jac module
neojac fmt src          # the one layout; CI runs `neojac fmt --check`
neojac test             # builds, then runs the vitest suite on what neojac emits
```

What CI runs, in order: `neojac check`, `neojac fmt --check src archwire.jac`, then the suite on the tree `neojac npm run build` lays out, on Linux, macOS and Windows.

- **Where things are:** each module is `src/<path>.jac`. `jac.toml` replaces `package.json` (neojac writes `package.json` from it; don't edit or commit that file). `archwire.jac` holds every import between the project's modules as a wire; `neojac fmt --fix archwire.jac` rewrites the wires from the sources. `src/host.jac` holds the small helpers for JavaScript values that Jac code shares, and `src/lazy.js` loads npm packages on first use.
- **Running the CLI from source:** `neojac npm run dev:cli -- <args>`.
- **Tests** stay in TypeScript under `test/` and import modules by their old `.js` paths, which neojac serves from forwarders. `neojac npx vitest run <file>` runs one file.

Run `neojac npx changeset` if your change affects users, and commit the file it generates.

### Keep the CLI's startup fast

Editors, agents and OpenSpec Desktop run the CLI many times, and each call pays for what it loads before the command runs. So a command loads only the command definitions and its own code:

- **Definitions** (name, options, help text) go in `src/cli/index.jac` or `src/cli/commands/<name>.jac`. The command's code is imported inside the action function (an import in a code body), with its `++>` wire in `archwire.jac`.
- **npm packages** (zod, yaml, tinyglobby, ora, chalk, `@inquirer/*`...) never get a top-level import: neojac loads every Jac module as the CLI starts, so a module takes a package through `need`/`load`/`pick` from `src/lazy.js`, where it is used. Add a new package to the tables there, so bundlers see it.

`test/cli-e2e/startup-modules.test.ts` checks which packages and command modules each command loads. When you add a command, add it to that test's list.

One cost is neojac's own: its boot module imports every compiled Jac module, so each run parses all of them (about 100 ms more than the TypeScript build's `openspec --version`), while a module's code runs only when it is first used. The suite and the start-up test run the same unbundled tree that ships, so it is not bundled to hide that.

## PR checklist

- Branch off `main` in your fork.
- Title it as a conventional commit: `type(scope): subject`, for example `fix(archive): keep authored Purpose`.
- If a coding agent wrote the code, say which agent and model, and confirm you tested it. AI-generated code is welcome when it has been verified.

Maintainers are listed in [MAINTAINERS.md](MAINTAINERS.md).
