// neojac cannot yet import an npm package inside a function (E5090), and it loads every Jac
// module when the CLI starts. These two load a package where it is first used instead.
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

/** The package's exports, loaded synchronously on first use. */
export const need = (name) => require(name);

/** The package's namespace, loaded with a real `import()` (which test mocks intercept). */
export const load = (name) => import(name);

/** One export of a package (its default unless named), as the value itself: reading a function
 *  off a package from Jac (`need("chalk").default`) gives a wrapper that loses its properties. */
export const pick = (name, key = 'default') => require(name)[key];
