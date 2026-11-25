// Preloaded with `node --import` by test/cli-e2e/startup-modules.test.ts.
// Records the URL of every module the process loads (built-ins excluded) and
// writes them, one per line, to the file named by OPENSPEC_TEST_MODULE_LOG
// when the process exits.
//
// Under neojac every Jac module's emission (.jac/src/<path>.mjs) is loaded as
// the CLI starts, and its code runs only when the module is started: by a
// forwarder, or by an import in a code body where that import runs. So each
// emission's `$run` is made to record its module's start too, as a line
// `started:<url>`.
import * as nodeModule from 'node:module';
import { appendFileSync, writeFileSync } from 'node:fs';

const logFile = process.env.OPENSPEC_TEST_MODULE_LOG;
const JAC_RUN = 'export function $run() {';
const recordStart = (url, source) =>
  url.includes('/.jac/src/') && url.endsWith('.mjs') && source.includes(JAC_RUN)
    ? source.replace(JAC_RUN, `${JAC_RUN} globalThis.__jacStarted.push(import.meta.url);`)
    : source;

if (logFile) {
  writeFileSync(logFile, '');
  globalThis.__jacStarted = [];
  process.on('exit', () => {
    if (globalThis.__jacStarted.length > 0) {
      appendFileSync(logFile, `\n${globalThis.__jacStarted.map((url) => `started:${url}`).join('\n')}\n`);
    }
  });
  if (typeof nodeModule.registerHooks === 'function') {
    // Node 22.15+/23.5+: synchronous, in-thread hooks that also see require().
    const loaded = [];
    nodeModule.registerHooks({
      load(url, context, nextLoad) {
        if (!url.startsWith('node:')) loaded.push(url);
        const result = nextLoad(url, context);
        if (result.source === undefined || result.source === null) return result;
        return { ...result, source: recordStart(url, String(result.source)) };
      },
    });
    process.on('exit', () => appendFileSync(logFile, loaded.join('\n')));
  } else {
    // Node 20: asynchronous hooks on the loader thread. They see every module
    // reached through `import`, which covers the CLI's own (ESM) modules and
    // the entry module of every package it imports.
    const hooks = `
      import { appendFileSync } from 'node:fs';
      const JAC_RUN = ${JSON.stringify(JAC_RUN)};
      export async function load(url, context, nextLoad) {
        if (!url.startsWith('node:')) appendFileSync(${JSON.stringify(logFile)}, url + '\\n');
        const result = await nextLoad(url, context);
        if (!url.includes('/.jac/src/') || !url.endsWith('.mjs') || result.source == null) return result;
        const source = String(result.source);
        return source.includes(JAC_RUN)
          ? { ...result, source: source.replace(JAC_RUN, JAC_RUN + ' globalThis.__jacStarted.push(import.meta.url);') }
          : result;
      }
    `;
    nodeModule.register(`data:text/javascript,${encodeURIComponent(hooks)}`);
  }
}
