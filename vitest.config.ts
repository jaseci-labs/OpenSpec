import { defineConfig } from 'vitest/config';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import type { Plugin } from 'vite';

// Every test runs with a throwaway home, so a test that forgets to isolate it
// can never write to the developer's real one (~/.minimax/skills,
// ~/.codex/prompts, the global config). Tests that need their own still set it.
const testHome = fs.mkdtempSync(path.join(os.tmpdir(), 'openspec-test-home-'));
process.env.OPENSPEC_TEST_HOME = testHome;

function resolveMaxWorkers(): number | undefined {
  // Allow callers (CI/agents) to override without editing config.
  const raw = process.env.VITEST_MAX_WORKERS;
  if (raw) {
    const parsed = Number(raw);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }

  // Vitest v3 defaults to `pool: "forks"` and scales worker processes with CPU.
  // This repo's tests can spawn many Node processes (CLI invocations, temp FS),
  // so cap parallelism to avoid runaway CPU/memory usage in automation.
  const cpuCount = typeof os.availableParallelism === 'function'
    ? os.availableParallelism()
    : os.cpus().length;
  return Math.min(4, Math.max(1, cpuCount));
}

// Under neojac the suite runs on what the node space emits: a Jac module is
// `.jac/src/<path>.mjs` and `src/<path>.ts` is its forwarder. Jac modules import
// each other's emissions, which a test's `vi.mock('../src/<path>.js')` (a mock
// of the forwarder) does not reach. In tests only, each Jac module's import of
// another is made to prefer the forwarder's export wherever a mock replaced it.
const MOCKABLE = '\0jac-mockable';
const mockableModule = `
const pending = (globalThis.__jacMockables ??= []);
export function mockable(forwarder, real, jsFn) {
  const state = { forwarder };
  pending.push(state);
  return new Proxy({}, {
    get(_, key) {
      const own = real[key];
      if (!state.seen || typeof key !== 'string') return own;
      let given;
      try { given = state.seen[key]; } catch { return own; }
      if (given === undefined || given === own) return own;
      if (typeof own === 'function' && jsFn && given === jsFn(own)) return own;
      return given;
    },
    has: (_, key) => key in real,
  });
}`;

function jacImportsSeeMocks(): Plugin {
  const emitted = `${path.sep}.jac${path.sep}src${path.sep}`;
  return {
    name: 'jac-imports-see-mocks',
    enforce: 'pre',
    resolveId: (id) => (id === 'virtual:jac-mockable' ? MOCKABLE : null),
    load: (id) => (id === MOCKABLE ? mockableModule : null),
    transform(code, id) {
      const at = id.indexOf(emitted);
      if (at < 0 || !id.endsWith('.mjs')) return null;
      const root = id.slice(0, at);
      let changed = false;
      const out = code.replace(/^import \* as (\$m\d+) from "([^"]+\.mjs)";$/gm, (line, name, spec) => {
        const target = path.resolve(path.dirname(id), spec);
        if (!target.startsWith(root + emitted)) return line;
        const forwarder = path.join(root, 'src', target.slice(root.length + emitted.length).replace(/\.mjs$/, '.ts'));
        if (!fs.existsSync(forwarder)) return line;
        changed = true;
        return `import * as ${name}$own from "${spec}";\nconst ${name} = $jacMockable(${JSON.stringify(forwarder)}, ${name}$own, typeof $j === "undefined" ? undefined : $j.js_fn);`;
      });
      return changed ? `import { mockable as $jacMockable } from "virtual:jac-mockable";\n${out}` : null;
    },
  };
}

export default defineConfig({
  plugins: [jacImportsSeeMocks()],
  test: {
    globals: true,
    environment: 'node',
    globalSetup: './vitest.setup.ts',
    setupFiles: ['./vitest.jac-mocks.ts'],
    // Opt the suite out of telemetry. Many tests spawn the real CLI, which runs
    // the preAction hook like any user invocation: it would persist an
    // anonymousId into the developer's *real* global config and POST a
    // command_executed event per spawn. Workers inherit this env, and so do the
    // CLI child processes they spawn. Telemetry's own tests delete these vars
    // before asserting, so they are unaffected.
    env: {
      OPENSPEC_TELEMETRY: '0',
      DO_NOT_TRACK: '1',
      HOME: testHome,
      USERPROFILE: testHome,
      XDG_CONFIG_HOME: path.join(testHome, '.config'),
      XDG_DATA_HOME: path.join(testHome, '.local', 'share'),
      XDG_STATE_HOME: path.join(testHome, '.local', 'state'),
      CODEX_HOME: path.join(testHome, '.codex'),

      // A scripted `openspec init` installs for the machine unless told
      // otherwise. The suite's project tests say so here, once; the tests of
      // that default clear it.
      OPENSPEC_SKILLS_SCOPE: 'project',
      GH_HOST: 'skills.example.invalid',
      GIT_CONFIG_GLOBAL: path.join(testHome, 'release', 'gitconfig'),
    },
    // Tests rely on per-file process isolation (e.g., `process.cwd()` assumptions).
    pool: 'forks',
    maxWorkers: resolveMaxWorkers(),
    include: ['test/**/*.test.ts'],
    coverage: {
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'dist/',
        'bin/',
        '*.config.ts',
        'build.js',
        'test/**'
      ]
    },
    testTimeout: 10000,
    hookTimeout: 10000,
    teardownTimeout: 3000
  }
});
