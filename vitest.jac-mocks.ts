import { beforeAll, beforeEach } from 'vitest';

// Once a test file's modules have loaded, let every Jac module's imports of other
// Jac modules see the test's mocks (vitest.config.ts, jacImportsSeeMocks). The
// forwarders are imported from here, outside any Jac module's import chain.
type Pending = { forwarder: string; seen?: unknown; loading?: Promise<void> };

const settle = async () => {
  const pending = (globalThis as { __jacMockables?: Pending[] }).__jacMockables ?? [];
  await Promise.all(
    pending.map((state) =>
      (state.loading ??= import(/* @vite-ignore */ state.forwarder).then(
        (ns) => { state.seen = ns; },
        () => {},
      )),
    ),
  );
};

beforeAll(settle);
beforeEach(settle);
