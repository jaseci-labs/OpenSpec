#!/usr/bin/env node

import module from 'node:module';

// Every run parses the whole compiled CLI (neojac's boot module imports each Jac
// module), so keep V8's compiled code between runs in Node's compile cache.
// NODE_DISABLE_COMPILE_CACHE=1 turns it off. The CLI is imported after this, or
// it would be compiled before the cache is on.
module.enableCompileCache?.();

const { runCli } = await import('../dist/cli/index.js');

runCli();
