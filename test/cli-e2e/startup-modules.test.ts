import { afterAll, describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { cliProjectRoot, ensureCliBuilt } from '../helpers/run-cli.js';

// Every CLI call pays for the modules it loads before the command runs, and
// callers such as editors and agents run the CLI many times. A command loads
// only the command definitions (names, options, help text) and its own
// implementation; everything else loads on demand.

const binPath = path.join(cliProjectRoot, 'bin', 'openspec.js');
const hookUrl = pathToFileURL(
  path.join(cliProjectRoot, 'test', 'helpers', 'record-loaded-modules.mjs')
).href;

// The module that implements each command, relative to dist/.
const COMMAND_IMPLEMENTATIONS: Record<string, string[]> = {
  init: ['core/init.js'],
  update: ['core/update.js'],
  list: ['core/list.js'],
  view: ['core/view.js'],
  archive: ['core/archive.js'],
  change: ['commands/change.js'],
  spec: ['commands/spec.js'],
  validate: ['commands/validate.js'],
  show: ['commands/show.js'],
  feedback: ['commands/feedback.js'],
  completion: ['commands/completion.js'],
  config: ['commands/config.js'],
  schema: ['commands/schema.js'],
  store: ['commands/store.js'],
  doctor: ['commands/doctor.js'],
  context: ['commands/context.js'],
  workset: ['commands/workset.js'],
  status: ['commands/workflow/status.js'],
  instructions: ['commands/workflow/instructions.js'],
  templates: ['commands/workflow/templates.js'],
  schemas: ['commands/workflow/schemas.js'],
  new: ['commands/workflow/new-change.js'],
};

const workDirs: string[] = [];

afterAll(() => {
  for (const dir of workDirs) {
    rmSync(dir, { recursive: true, force: true });
  }
});

// Under neojac a Jac module is emitted to .jac/src/<path>.mjs, and its dist/
// forwarder loads only for TypeScript callers. Every emitted Jac module is parsed
// as the CLI starts (neojac's boot module imports them all) and started only when
// first used, so `own` sees only what is still TypeScript; npm packages, the
// part of start-up these tests can still pin, load only on first use.
function loadedModules(args: string[], withProject = false): {
  own: string[];
  jacModules: string[];
  packages: Set<string>;
  status: number | null;
} {
  const workDir = mkdtempSync(path.join(os.tmpdir(), 'openspec-startup-'));
  workDirs.push(workDir);
  if (withProject) {
    mkdirSync(path.join(workDir, 'openspec', 'changes'), { recursive: true });
    mkdirSync(path.join(workDir, 'openspec', 'specs'), { recursive: true });
  }
  const logFile = path.join(workDir, 'modules.log');
  const result = spawnSync(process.execPath, ['--import', hookUrl, binPath, ...args], {
    cwd: workDir,
    env: {
      ...process.env,
      OPENSPEC_TELEMETRY: '0',
      OPEN_SPEC_INTERACTIVE: '0',
      XDG_CONFIG_HOME: path.join(workDir, 'config'),
      XDG_DATA_HOME: path.join(workDir, 'data'),
      OPENSPEC_TEST_MODULE_LOG: logFile,
    },
    encoding: 'utf-8',
    timeout: 30_000,
    windowsHide: true,
  });
  expect(result.error).toBeUndefined();

  // Loaded module URLs use real paths, so compare against the real dist/ path
  // in case the checkout path goes through a symlink or a Windows short name.
  const distRoot = realpathSync.native(path.join(cliProjectRoot, 'dist'));

  const urls = readFileSync(logFile, 'utf-8').split('\n').filter(Boolean);
  const own: string[] = [];
  const jacModules: string[] = [];
  const jacRoot = realpathSync.native(path.join(cliProjectRoot, '.jac', 'src'));
  const packages = new Set<string>();
  for (const url of urls) {
    if (!url.startsWith('file:')) continue;
    const file = fileURLToPath(url);
    const segments = file.split(path.sep);
    const lastNodeModules = segments.lastIndexOf('node_modules');
    if (lastNodeModules !== -1) {
      const name = segments[lastNodeModules + 1];
      packages.add(name.startsWith('@') ? `${name}/${segments[lastNodeModules + 2]}` : name);
    } else if (file.startsWith(distRoot + path.sep)) {
      own.push(path.relative(distRoot, file).split(path.sep).join('/'));
    } else if (file.startsWith(jacRoot + path.sep)) {
      jacModules.push(path.relative(jacRoot, file).split(path.sep).join('/').replace(/\.mjs$/, '.js'));
    }
  }
  // An empty list means the paths didn't match, and every absence check
  // below would pass without checking anything.
  expect(own).not.toEqual([]);
  return { own, jacModules, packages, status: result.status };
}

// A command implemented in Jac is started by a Jac caller's import of its
// emission, which a load hook cannot tell from the parse every Jac module gets
// at start-up; only its dist/ forwarder (a TypeScript caller's import) shows.
function isJac(command: string): boolean {
  return COMMAND_IMPLEMENTATIONS[command].every((module) =>
    existsSync(path.join(cliProjectRoot, '.jac', 'src', module.replace(/\.js$/, '.mjs')))
  );
}

// No other command's implementation loaded, and this one's did where that is visible.
function expectOnlyImplementation(own: string[], command: string): void {
  const loaded = implementationsLoaded(own);
  expect(loaded.filter((other) => other !== command)).toEqual([]);
  if (!isJac(command)) expect(loaded).toContain(command);
}

function implementationsLoaded(own: string[]): string[] {
  return Object.entries(COMMAND_IMPLEMENTATIONS)
    .filter(([, modules]) => modules.some((module) => own.includes(module)))
    .map(([command]) => command);
}

describe('CLI startup loads only what the command needs', () => {
  it.each(['--version', '--help', 'validate --help'])(
    '`openspec %s` loads the command definitions and nothing else',
    async (invocation) => {
      await ensureCliBuilt();
      const { own, packages, status } = loadedModules(invocation.split(' '));

      expect(status).toBe(0);
      expect([...packages]).toEqual(['commander']);
      expect(implementationsLoaded(own)).toEqual([]);
    }
  );

  // Shell completion scripts run `__complete` on every Tab press. It needs no
  // package beyond commander, and never telemetry: tracking would hold each
  // press open for the request.
  it.each(['changes', 'specs'])(
    '`openspec __complete %s` loads only commander and no telemetry',
    async (type) => {
      await ensureCliBuilt();
      const { own, packages, status } = loadedModules(['__complete', type]);

      expect(status).toBe(0);
      expect([...packages]).toEqual(['commander']);
      expect(implementationsLoaded(own)).toEqual(['completion']);
      expect(own).not.toContain('telemetry/index.js');
    }
  );

  it('`openspec __complete schemas` loads the schema reader but not tinyglobby or ora', async () => {
    await ensureCliBuilt();
    const { own, jacModules, packages, status } = loadedModules(['__complete', 'schemas']);

    expect(status).toBe(0);
    expect([...packages]).not.toContain('fast-glob');
    expect([...packages]).not.toContain('tinyglobby');
    expect([...packages]).not.toContain('brace-expansion');
    expect([...packages]).not.toContain('ora');
    expect(own).not.toContain('telemetry/index.js');
    // The name promises a schema reader, so pin it: the resolver directly, not
    // the artifact-graph barrel, which re-exports it but also pulls outputs.js
    // and with it tinyglobby. The resolver is a Jac module, which its Jac callers
    // reach through its emission rather than its dist/ forwarder.
    expect(
      own.includes('core/artifact-graph/resolver.js') || jacModules.includes('core/artifact-graph/resolver.js')
    ).toBe(true);
    expect(own).not.toContain('core/artifact-graph/index.js');
  });

  // Negative control for the two cases above. `isTabCompletionRun` matches the
  // command path exactly, unlike the adjacent `isCompletionRun`, which
  // prefix-matches `completion:*`. Widening one into the other would silently
  // stop tracking every user-facing command in that group, and every assertion
  // above would still pass.
  it.each([['list --json'], ['completion generate zsh']])(
    '`openspec %s` still reaches the telemetry hooks',
    async (invocation) => {
      await ensureCliBuilt();
      const { own } = loadedModules(invocation.split(' '));

      expect(own).toContain('telemetry/index.js');
      expect(own).toContain('core/completion-tip.js');
    }
  );

  // The module-count assertions above pin that telemetry is not LOADED. They do
  // not pin the user-visible consequence, which is the reason the skip exists:
  // the first-run disclosure goes to stderr, every generated completion script
  // sends `__complete` stderr to /dev/null, and `maybeShowTelemetryNotice` marks
  // `noticeSeen` before `trackCommand` re-reads it. So before this change a
  // user's first-ever interaction being a Tab press burned the disclosure where
  // nobody could read it and began collecting on that same press.
  //
  // Telemetry is deliberately left ENABLED here: the point is that an enabled
  // run still records nothing. HOME must be isolated as well as XDG_CONFIG_HOME,
  // or `migrateLegacyTelemetryConfig` imports the developer's real config from
  // ~/.config/openspec/config.json and the test passes vacuously.
  it('`openspec __complete` leaves the first-run telemetry notice unconsumed', async () => {
    await ensureCliBuilt();
    const home = mkdtempSync(path.join(os.tmpdir(), 'openspec-notice-'));
    workDirs.push(home);
    const configHome = path.join(home, 'config');

    // These have to be DELETED, not blanked. Both opt-outs read as "set to
    // anything that is not an explicit on-value", so `OPENSPEC_TELEMETRY: ''`
    // and `DO_NOT_TRACK: ''` would switch telemetry OFF and the assertions
    // below would hold on any build, passing vacuously.
    const env = {
      ...process.env,
      HOME: home,
      USERPROFILE: home,
      XDG_CONFIG_HOME: configHome,
      XDG_DATA_HOME: path.join(home, 'data'),
    };
    delete env.OPENSPEC_TELEMETRY;
    delete env.DO_NOT_TRACK;
    delete env.CI;

    const result = spawnSync(process.execPath, [binPath, '__complete', 'changes'], {
      cwd: home,
      env,
      encoding: 'utf-8',
      timeout: 30_000,
      windowsHide: true,
    });

    expect(result.status).toBe(0);
    // No disclosure written to a stream the completion scripts discard.
    expect(result.stderr).toBe('');
    // And no config file, so neither noticeSeen nor an anonymousId was minted.
    expect(existsSync(path.join(configHome, 'openspec', 'config.json'))).toBe(false);
  });

  it.each([
    ['config list --json', 'config'],
    ['config path', 'config'],
    ['store list --json', 'store'],
    ['doctor --json', 'doctor'],
    ['schemas --json', 'schemas'],
    ['list --json', 'list'],
  ])('`openspec %s` loads only the %s implementation', async (invocation, command) => {
    await ensureCliBuilt();
    const { own } = loadedModules(invocation.split(' '));

    expectOnlyImplementation(own, command);
  });

  it.each([
    ['status --json', 'status'],
    ['validate --all --json', 'validate'],
    ['templates --json', 'templates'],
    ['new change probe --json', 'new'],
  ])('`openspec %s` does not load ora', async (invocation, command) => {
    await ensureCliBuilt();
    const { own, packages, status } = loadedModules(invocation.split(' '), true);

    expect(status).toBe(0);
    expectOnlyImplementation(own, command);
    expect([...packages]).not.toContain('ora');
  });
});
