// neojac loads every Jac module as the CLI starts, and cannot yet import an npm package
// inside a function (E5090). Jac modules load packages through these helpers instead, where
// first used. Each package is named statically below so a bundler (the standalone binary's)
// sees it; any other name falls back to a plain require or import.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);

const required = {
  '@inquirer/core': () => require('@inquirer/core'),
  '@inquirer/prompts': () => require('@inquirer/prompts'),
  'brace-expansion': () => require('brace-expansion'),
  chalk: () => require('chalk'),
  commander: () => require('commander'),
  'cross-spawn': () => require('cross-spawn'),
  diff: () => require('diff'),
  http: () => require('node:http'),
  https: () => require('node:https'),
  ora: () => require('ora'),
  picomatch: () => require('picomatch'),
  skills: () => require('skills'),
  tinyglobby: () => require('tinyglobby'),
  yaml: () => require('yaml'),
  zod: () => require('zod'),
};

const imported = {
  '@inquirer/core': () => import('@inquirer/core'),
  '@inquirer/prompts': () => import('@inquirer/prompts'),
  ora: () => import('ora'),
  skills: () => import('skills'),
};

/** The package's exports, loaded synchronously on first use. */
export const need = (name) => (required[name] ?? (() => require(name)))();

/** The package's namespace, loaded with a real `import()` (which test mocks intercept). */
export const load = (name) => (imported[name] ?? (() => import(name)))();

/** One export of a package (its default unless named), as the value itself: reading a function
 *  off a package from Jac (`need("chalk").default`) gives a wrapper that loses its properties. */
export const pick = (name, key = 'default') => need(name)[key];

/** The package's root directory: the one holding package.json and schemas/ (this file is src/lazy.js). */
export const packageRoot = () => fileURLToPath(new URL('..', import.meta.url));

/** The package's own package.json, by a static path a bundler can include. */
export const packageJson = () => require('../package.json');
