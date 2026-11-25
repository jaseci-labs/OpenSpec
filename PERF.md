# Performance of the Jac rewrite

This compares three builds of the OpenSpec CLI on the same inputs:

- **original**: the TypeScript code before the rewrite (`f1cd852f4`), built with its own `tsc` build;
- **Jac before**: the Jac rewrite as the `neojac-deslop` branch left it (`e629af7`);
- **Jac after**: this branch, `neojac-perf`.

All three run on the Node that neojac 0.5.1 ships (v26.13.0), on a shared 20-core Linux machine.

## What runs where

`archwire.jac` declares one space, `space openspec: node { "."; }`. Every Jac module is
compiled to JavaScript and runs on Node. Nothing in this repository is compiled to machine
code: there is no `native` space, and no `cpython` space. So the Jac build's speed is Node's
speed running what neojac emits, plus neojac's runtime (`.jac/@jac/core.js`), which gives the
emitted code Python's semantics. The emitted code is also laid out differently: every module
loads at start-up.

The CLI has no server, so the archwire declares no endpoints and there are none to measure
(`.jac/__main.mjs` starts a server only when there are endpoints). The workloads are the CLI's
commands and the test suite.

## How it was measured

- **Commands**: [`perf/bench.py`](perf/bench.py)
  `ORIGINAL_ROOT JAC_BEFORE_ROOT JAC_AFTER_ROOT RUNS`, where each root is a tree with
  `bin/openspec.js` (for Jac, `.jac/test/spaces/openspec` after `neojac npm run build`). Its
  `NODE` and `FIXTURE_SRC` constants name this machine's paths. For each workload it makes one warm-up run
  of each build, then 11 rounds. Each round runs all three builds, and the order rotates from
  round to round. The table gives the median wall time. Every run gets an isolated `HOME`/XDG
  directory, `OPENSPEC_TELEMETRY=0`, `OPENSPEC_NO_UPDATE_CHECK=1`, `NO_COLOR=1` and `CI=1`.
- **Inputs**: a git repository holding a copy of the original repository's own `openspec/`
  directory: 44 specs, 5 active changes and 108 archived ones. `init --tools all` runs in a
  fresh empty repository each time, and `update` in a fresh one that was `init`ed first.
- **Same output**: for each workload the harness compares stdout, stderr and the exit code of
  every run of every build. For `init` and `update` it also compares a hash of every file
  they wrote. Timing fields (`durationMs`) and temporary paths are normalised. All three
  builds gave identical output on every workload, in all 11 runs.
- **Load**: the machine is shared. The load average was 10.9 when the command benchmark
  started and 45.7 when it ended (20 cores). The rotation spreads this over the three builds,
  but single numbers are noisy: treat differences under about 10% as noise. During
  development I compared changes with A/B runs of 10–20 alternated launches, and read CPU
  profiles (`node --cpu-prof`), which show proportions and do not depend on the load.

## Commands: before and after

Median wall time in ms, 11 runs each.

| Workload | original | Jac before | Jac after | before ÷ original | after ÷ original | after vs before |
|---|---:|---:|---:|---:|---:|---:|
| `--version` | 50 | 199 | 110 | 3.99× | 2.20× | −45% |
| `--help` | 52 | 198 | 111 | 3.78× | 2.13× | −44% |
| `list` | 152 | 290 | 183 | 1.91× | 1.20× | −37% |
| `list --specs --json` | 154 | 383 | 220 | 2.49× | 1.43× | −43% |
| `list --all --json` | 291 | 512 | 370 | 1.76× | 1.27× | −28% |
| `validate --all --json` | 226 | 696 | 363 | 3.08× | 1.60× | −48% |
| `validate --specs --strict` | 189 | 552 | 297 | 2.93× | 1.58× | −46% |
| `show <spec> --json` | 159 | 288 | 179 | 1.81× | 1.12× | −38% |
| `show <change> --json` | 157 | 285 | 182 | 1.81× | 1.16× | −36% |
| `view` | 186 | 428 | 264 | 2.30× | 1.42× | −38% |
| `status --change … --json` | 155 | 291 | 189 | 1.88× | 1.22× | −35% |
| `instructions proposal --json` | 156 | 289 | 186 | 1.85× | 1.19× | −36% |
| `schemas --json` | 142 | 272 | 173 | 1.92× | 1.22× | −36% |
| `templates --json` | 143 | 267 | 168 | 1.86× | 1.18× | −37% |
| `doctor --json` | 127 | 266 | 165 | 2.09× | 1.30× | −38% |
| `context --json` | 129 | 267 | 169 | 2.07× | 1.31× | −37% |
| `config list --json` | 136 | 284 | 171 | 2.09× | 1.26× | −40% |
| `init --tools all` (fresh repo) | 943 | 1249 | 1013 | 1.32× | 1.07× | −19% |
| `update` (after init) | 459 | 1032 | 629 | 2.25× | 1.37× | −39% |

The Jac build is still slower than the original on every command: by about 60 ms of
start-up, plus 10–60% on the commands that parse many specs. Where that cost comes from,
and why it stays, is under [Blockers](#what-neojac-blocks).

## Test suite: before and after

`neojac npx vitest run` (vitest 5, at most 4 forked workers) on each tree, all 6,527 tests, run
in two rounds in the order original → Jac before → Jac after, then the reverse
([`perf/suites.sh`](perf/suites.sh)). The load moved a lot (54 → 12 over the runs), so CPU time
(user + system, every process the suite starts) is the steadier figure.

| Suite run | original | Jac before | Jac after |
|---|---:|---:|---:|
| Round 1, wall s (load at start) | 225.3 (54.7) | 335.8 (44.6) | 171.6 (21.6) |
| Round 2, wall s (load at start) | 94.0 (12.3) | 196.0 (15.0) | 139.3 (30.3) |
| Round 1, CPU s | 616.6 | 1135.7 | 714.6 |
| Round 2, CPU s | 438.8 | 917.1 | 665.4 |
| **Mean CPU s** | **527.7** | **1026.4** | **690.0** (−33% vs before; 1.31× original) |
| Failed tests | 10, 9 | 12, 12 | 10, 10 |

The failures are the same in every tree but two. The 8 `config-edit` tests and 1 `store-git`
test fail on this machine for the original too (they spawn an editor and expect an
interactive git prompt). `global-skills` fails in the Jac branches' repository because
`.agents/skills/` there also holds neojac's installed skills, which lack the
`metadata: internal: true` that test asks for; it passes in the "Jac before" worktree, which
does not have them. "Jac before" also fails `cli-e2e/basic` in that worktree. Round 1 of the
original had one `init.test.ts` failure at load 54 that round 2 did not repeat. No test that
passed before fails after.

The suite's largest gains came from two places. Its CLI runs now start with the compile cache
and the resolve hook (`artifact-workflow.test.ts`: 49 s → 24 s, original 22 s). And the
in-process `init`/`update` tests no longer make an exception per missing path
(`init.test.ts`: 29 s → 15 s, run alone).

## What made the difference

Profiles showed the same causes over and over. Here they are in the order the commits deal
with them.

### Start-up (every command)

Jac before spent about 150 ms of a 200 ms `--version` before the command ran. The original
spends about 10 ms there. The reason is that neojac's boot module (`.jac/__boot.mjs`) imports
every compiled Jac module, all 226 of them, about 2.4 MB of JavaScript. An `import` inside a
function body is also emitted as a top-level static import (see blockers 1 and 2). The
original loads only the command it runs. The profile of `openspec --help` broke down like this:

| Part of start-up | Before | What changed |
|---|---:|---|
| Resolving about 6,600 relative `import` statements (stat + realpath each) | ~88 ms | A resolve hook (`module.registerHooks`) maps the package's own relative `.mjs`/`.js` imports straight to their URL. Node's modules and npm packages resolve as before. |
| Compiling 2.4 MB of modules | ~48 ms | `module.enableCompileCache()`: V8's code is cached between runs. |
| `node:http`/`node:https` imported at start-up (evaluates undici) | ~10–50 ms | `version-check` loads them through `src/lazy.js` on its first request. |

The first two live in `bin/start.mjs`, which `bin/openspec.js` imports before the CLI. Both
are plain Node APIs (Node ≥ 22.15, and the package needs ≥ 22.20). Neither changes what runs:
the hook only skips Node's lookup for files that are plain files inside the package. The
compile cache writes to `os.tmpdir()/node-compile-cache`, and `NODE_DISABLE_COMPILE_CACHE=1`
turns it off.

### Code that ran in neojac's runtime helpers

What the emitted code spends its time on is neojac's runtime giving Jac Python's semantics.
Some idioms of the port turned out far more expensive than their TypeScript originals. A
microbenchmark against `core.js` ([`perf/runtime-idioms.mjs`](perf/runtime-idioms.mjs), 2,000 lines per call, Node 26) shows the gap:

| Idiom, as emitted | µs per 2,000 items | The faster form, as emitted | µs |
|---|---:|---|---:|
| `for (i, line) in enumerate(lines)`: a `Tuple` per item, then unpacked | 2,346 | `for i in range(len(lines)) { line = lines[i]; }` | 11 |
| `found(line, pattern)`: `new RegExp` plus a dynamic `callattr(...,"test")` per call | 465 | a regex literal (original) | 39 |
| `rec(a=…, b=…)` via `fromEntries(list(fields.items()))` | 11,374 | `Object(fields)`: the dict converted once | 305 |
| `getattr(o, "value")` on a JS object | 106 | `o.value` | 8 |

The changes:

- **`src/host.jac`**: `sub`, `found`, `matchOf` and the new `splitBy` keep one `RegExp` per
  pattern and flags, keyed by flags and then by the pattern string. They reset `lastIndex`
  for `g`/`y`, so each use starts at the string's beginning, as a fresh expression would. A
  pattern that is itself a `RegExp` is still made fresh. They call `RegExp.prototype.test`/`exec`
  and `String.prototype.split`/`trim` directly, not through the runtime's dynamic method call.
  `rec` converts its dict to an object in one step. Keying by `flags + "/" + pattern` was
  itself slow: the concatenated key is a new string that the Map hashes on every call.
- **Parsers and validator**: the per-line loops over specs (`spec-structure`,
  `requirement-blocks`, `requirement-text`, `markdown-parser`, `specs-apply`, `validator`,
  `task-numbering`, `purpose-placeholder`, `schema`, `status`) walk by index, not with
  `enumerate`. Each of those lists is never changed during its loop, and each is always a list.
  `MarkdownParser` reads `self.lines` once per scan, and skips the header regex on lines that
  don't start with `#` (both header patterns are anchored on `#`).
- **Tool lookups**: five modules each found a tool with `AI_TOOLS.find(lambda …)`, through
  dynamic attribute reads, for every tool and every path `update` checks. `config.jac` now
  keeps a table by id (the first tool with each id, as `find` returned) and exports `findTool`.
  `readListFileTools` no longer rebuilds a set of every tool id on each read.

### Exceptions from the file system

A JavaScript error caught by Jac code goes through `caught()`, which builds a new
`BaseException`, an `Error` whose stack is captured a second time. Checking project paths
throws `ENOENT` for every path that isn't written yet. In `init.test.ts` that was 5 of 29
seconds. `canonicalizePotentialPath`, `isSymbolicLink`, the disk view's `isDirectory` and
`linkTarget`, and the update plan's `entryKind` and `isLink` now pass `throwIfNoEntry: false`.
A missing entry comes back as `undefined` and goes down the branch the `ENOENT` used to.
`ENOTDIR` and every other error still throw, which I checked on Node 26.

### The test suite's CLI runs

`test/helpers/run-cli.ts` spawns `node dist/cli/index.js`, not `bin/openspec.js`, so each of
its several hundred CLI runs started without the compile cache and the resolve hook. It now
preloads `bin/start.mjs` with `--import`, so a spawned CLI starts the way an installed one does.

## What neojac blocks

Each item below was reproduced with neojac 0.5.1 (`060988d8fbd5`) in a scratch project made of
`jac.toml` (`[project] name = "…"`) and the files shown.

### 1. An import in a function body still loads the module at start-up

The way to keep a command's code off start-up would be to import it where it is used. neojac
hoists such an import to a static top-level import. It only defers the module's top-level code
(`$start()`), so the module is still read, compiled and linked as the program starts.

```jac
# archwire.jac: space cli: node { entry main; heavy; }   heavy ++> main { work }
# main.jac
def run(flag: bool) {
    if flag {
        import from heavy { work }
        print(work());
    }
}
with entry { run(False); }
```

`neojac emit-js cli -o out` writes `main.mjs` starting with:

```js
import * as $boot from "./__boot.mjs";
import * as $m0 from "./heavy.mjs";        // hoisted: loaded even though run(False)
export function run(flag) { if (flag) { $m0.$start(); ... } }
```

On top of that, `__boot.mjs` imports every module of the space: here, all 226. A node space
has no dynamic `import()` of a Jac module, so start-up always loads the whole program. This is
the ~60 ms that the Jac build's `--version` still takes over the original's (110 vs 50 ms).

### 2. An npm or Node import inside a function: E5090

```jac
def run(flag: bool) {
    if flag {
        import from "node:http" { default as http }
        print(http.STATUS_CODES[200]);
    }
}
```

```
main.jac:3:9: error[E5090]: neojac does not support an import here yet
```

That is why the project loads packages through `src/lazy.js` (`need`/`load`/`pick`). This
branch puts `node:http` and `node:https` there too.

### 3. A native space can't speed up a node-space CLI

The obvious way to get machine-code speed for the parsers would be a `native` space that the
CLI's node space calls. Two things stop that:

- **A call from a node space into a native space is an HTTP request**, even when the archwire
  can describe both. With `space fast: native { parse; }`, `space cli: node { entry main; }` and
  `parse ++> main { countHeaders }`, the emitted call is
  `post("fast", "countHeaders", "/__jac/call/fast/parse/countHeaders", …)`. The native space has
  to be running as a server, and the node side needs `[apps.<app>.remote]` or
  `JAC_REMOTE_FAST`. Built with separate apps (`app svc { run fast; }`,
  `app tool { run cli; }`), a call measured **0.66 ms per crossing** on localhost (500 calls).
  `validate --all` makes thousands of parser calls and takes 363 ms in total, so one crossing
  per file would cost more than the parsing it replaces. It would also mean a background
  server for a one-shot CLI.
- **Running both spaces in one process fails to build.** `app tool { run fast, cli; }` (native
  plus node, Node embedded in the native program) gives, in `/tmp` and under `$HOME` alike:

  ```
  jac.toml:1:1: error[E2231]: '/home/jayanaka/.neojac/0.5.1/lib/node/crates/Cargo.toml' is a module of the project 'cross', and no archwire.jac governs it: …
  ```

  The file it names is in neojac's own installation, not in the project.

Making the whole CLI a native program would also change what ships: the npm package that runs
on any Node ≥ 22.20, on Windows too, and the modules the vitest suite imports through
`dist/*.js`. That is a change of product, not of speed.

### 4. Runtime costs with no way around them in Jac source

- **No object literal.** A JavaScript object is built as a Jac dict and then converted
  (`rec(**fields)` makes `dict_of([...])` and then `plain(...)`). neojac's own port guide
  writes `{a: 1}` as `Object.fromEntries([("a", 1)])`, which is slower still. `rec` is called
  about 1,000 times in the source. After this branch it costs ~0.15 µs per field instead of
  ~2.8 µs, but a literal would cost ~0.01 µs.
- **`Tuple` creation is slow** (`tup = (...a) => Tuple.from(a)` on an `Array` subclass with a
  species getter: ~0.5 µs each). Every `enumerate`, `zip`, `dict.items()` and tuple return pays
  it. I removed it from the hot loops; the rest run once per requirement block or less.
- **A value typed `any` is read and called through `getattr`/`callattr`**, which check Jac's
  own types first: about 13× a direct property read. JavaScript objects (parsed specs, options,
  `rec`s) are all `any`.
- **Each caught JavaScript error is wrapped in a new `BaseException`**, a second `Error` with
  its own stack capture. That is cheap to avoid only where the API can report "missing"
  without throwing (as above). Async `fs.promises.stat` has no such option, so those catches
  remain.
- **A runtime type check on a parameter typed `str` is compiled away.**
  `isinstance(pattern, str)` with `pattern: str` emits `pattern !== undefined`, so a `RegExp`
  passed where the signature says `str` (as the code does in places) passes the check. The
  parameter had to be retyped `any` to test it. And `rx(pattern)` with an `any` argument emits
  `as_(pattern, "s")`, which raises on a `RegExp`.

### 5. Tooling notes (no effect on speed, but they cost time)

- `neojac fmt --fix archwire.jac` did not add the wires for a function newly used from another
  module (`findTool`, `splitBy`), nor drop wires left unused (`E1146`). I edited them by hand.
- Jac source may hold no comments or docstrings (`W3050`/`W3051`). The reasons for these
  changes are in the commit messages.

## Not done, and why

- **Bundling the CLI into one file.** I measured it: rolldown over `dist/cli/index.js`, with
  npm packages left external and the compile cache on, gives `--version` in 72 ms against
  111 ms. That is the remaining start-up gap, nearly halved. It is not taken: CONTRIBUTING.md
  says the suite and the start-up test run the unbundled tree that ships.
  `test/cli-e2e/startup-modules.test.ts` checks per-module loading, which a bundle would make
  meaningless.
- **Merging the 35 small `command-generation/adapters/*` modules**: about 5 ms of start-up,
  but the tests import them by path.
