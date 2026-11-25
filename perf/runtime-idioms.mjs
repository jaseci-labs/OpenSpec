import * as $j from '../.jac/test/spaces/openspec/.jac/@jac/core.js';
const lines = Array.from({length: 2000}, (_, i) => (i % 7 ? 'text line ' + i : '## head ' + i));
function bench(name, f) { for (let i = 0; i < 20; i++) f(); const t = performance.now(); for (let i = 0; i < 200; i++) f(); console.log(name.padEnd(42), ((performance.now() - t) / 200 * 1000).toFixed(1), 'us per 2000 lines'); }
bench('enumerate + unpack (what neojac emits)', () => { let n = 0, i, line, $1, $2; for ($1 of $j.enumerate(lines, 0)) { $2 = $j.unpack($1, 2); i = $2[0]; line = $2[1]; if (line.startsWith('#')) n += i; } return n; });
bench('range(len()) + index (what neojac emits)', () => { let n = 0, i, line, $1, $2; for ($1 = 0, $2 = lines.length; $1 < $2; $1 += 1) { i = $1; line = $j.at(lines, i); if (line.startsWith('#')) n += i; } return n; });
bench('found(): new RegExp + callattr per call', () => { let n = 0; for (const l of lines) if ($j.as_($j.callattr(new RegExp('^##\\s+', ''), 'test', [l], undefined), 'b')) n++; return n; });
bench('regex literal (TypeScript original)', () => { let n = 0; for (const l of lines) if (/^##\s+/.test(l)) n++; return n; });
const o = {value: 'x'};
bench('getattr(o, "value") on a JS object', () => { let n = 0; for (const l of lines) if ($j.eq($j.getattr(o, 'value'), l)) n++; return n; });
bench('o.value', () => { let n = 0; for (const l of lines) if (o.value === l) n++; return n; });
bench('rec(a=..,b=..): dict_of + plain', () => { let r; for (const l of lines) r = globalThis.Object.fromEntries($j.plain($j.list($j.dict_items($j.dict_of([['a', l], ['b', 1]]))))); return r; });
bench('{a, b} object literal', () => { let r; for (const l of lines) r = {a: l, b: 1}; return r; });
bench('rec new: Object(plain(dict_of))', () => { let r; for (const l of lines) r = globalThis.Object($j.plain($j.dict_of([['a', l], ['b', 1]]))); return r; });
bench('dict_of alone', () => { let r; for (const l of lines) r = $j.dict_of([['a', l], ['b', 1]]); return r; });
bench('tup alone', () => { let r; for (const l of lines) r = $j.tup(1, l); return r; });
