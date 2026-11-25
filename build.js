#!/usr/bin/env node

import { execFileSync } from 'child_process';
import { existsSync, readdirSync, rmSync } from 'fs';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);

const runTsc = (args = []) => {
  const tscPath = require.resolve('typescript/bin/tsc');
  execFileSync(process.execPath, [tscPath, ...args], { stdio: 'inherit' });
};

console.log('🔨 Building OpenSpec...\n');

// The sources are Jac. Here, at the repository's root, src/ holds no TypeScript:
// `neojac npm run build` builds the tree neojac lays out, where each Jac module's
// TypeScript forwarder is compiled.
const hasTypeScript = (dir) =>
  existsSync(dir) &&
  readdirSync(dir, { recursive: true }).some((file) => /\.(m|c)?ts$/.test(String(file)));
if (!hasTypeScript('src')) {
  console.log('src/ holds Jac sources: build with `neojac npm run build`.');
  process.exit(0);
}

// Clean dist directory
if (existsSync('dist')) {
  console.log('Cleaning dist directory...');
  rmSync('dist', { recursive: true, force: true });
}

// Run TypeScript compiler (use local version explicitly)
console.log('Compiling TypeScript...');
try {
  runTsc(['--version']);
  runTsc();
  console.log('\n✅ Build completed successfully!');
} catch (error) {
  console.error('\n❌ Build failed!');
  process.exit(1);
}
