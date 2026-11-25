// What the CLI's start needs before its modules load; bin/openspec.js imports it
// first, and the test suite preloads it (`node --import`) where it runs
// dist/cli/index.js. Every run loads the whole compiled CLI: neojac's boot module
// imports each Jac module, and the modules import each other by thousands of
// relative paths.

import module from 'node:module';

// Keep V8's compiled code between runs in Node's compile cache
// (NODE_DISABLE_COMPILE_CACHE=1 turns it off).
module.enableCompileCache?.();

// Resolve the package's own relative imports of its ES modules straight to the
// file they name. Node's resolver would otherwise stat and realpath each one; the
// package's files are plain files, so the URL is the same. Anything else (Node's
// modules, npm packages) is resolved as usual.
const root = new URL('../', import.meta.url).href;
const packages = `${root}node_modules/`;
module.registerHooks?.({
  resolve(specifier, context, nextResolve) {
    const parent = context.parentURL;
    if (
      parent !== undefined &&
      parent.startsWith(root) &&
      (specifier.startsWith('./') || specifier.startsWith('../')) &&
      (specifier.endsWith('.mjs') || specifier.endsWith('.js'))
    ) {
      const url = new URL(specifier, parent).href;
      if (url.startsWith(root) && !url.startsWith(packages)) {
        return { url, format: 'module', shortCircuit: true };
      }
    }
    return nextResolve(specifier, context);
  },
});
