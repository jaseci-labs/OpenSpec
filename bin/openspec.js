#!/usr/bin/env node

import './start.mjs';

// Imported after start.mjs has set up the compile cache and the resolve hook,
// so they apply to it.
const { runCli } = await import('../dist/cli/index.js');

runCli();
