/**
 * Durability tests for native.js
 *
 * A year of practice lives in localStorage, which iOS is entitled to reclaim.
 * native.js mirrors it into Preferences and a JSON file and restores from them.
 * That code is only ever exercised on the day something has gone wrong, which
 * is exactly why it needs a test — the failure mode is silent data loss.
 *
 * Boots the real native.js against mocked Capacitor plugins. No iOS required.
 *
 *   npm test
 */

import vm from 'node:vm';
import fs from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SRC = fs.readFileSync(join(HERE, '..', 'src', 'native.js'), 'utf8');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// The durable stores. These deliberately survive a webview data wipe.
const prefs = new Map();
const files = new Map();

let failures = 0;
function check(label, actual, expected) {
  const ok = String(actual) === String(expected);
  if (!ok) failures++;
  console.log(`  ${label.padEnd(16)}: ${String(actual).padEnd(4)} ${ok ? '✓' : `✗ expected ${expected}`}`);
}

function makeLocalStorage(seed = {}) {
  const m = new Map(Object.entries(seed));
  return {
    get length() { return m.size; },
    key: (i) => [...m.keys()][i] ?? null,
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: (k) => m.delete(k),
    _keys: (p) => [...m.keys()].filter((k) => k.startsWith(p)),
  };
}

function boot(localStorage) {
  let reloads = 0;
  const Plugins = {
    Preferences: {
      get: ({ key }) => Promise.resolve({ value: prefs.has(key) ? prefs.get(key) : null }),
      set: ({ key, value }) => { prefs.set(key, String(value)); return Promise.resolve(); },
      remove: ({ key }) => { prefs.delete(key); return Promise.resolve(); },
    },
    Filesystem: {
      writeFile: ({ path, data }) => { files.set(path, data); return Promise.resolve(); },
      readFile: ({ path }) => files.has(path)
        ? Promise.resolve({ data: files.get(path) })
        : Promise.reject(new Error('ENOENT')),
    },
  };

  const win = { Capacitor: { isNativePlatform: () => true, Plugins }, addEventListener() {}, React: undefined };
  const ctx = vm.createContext({
    window: win,
    localStorage,
    navigator: {},
    console: { log() {} },              // silence native.js diagnostics
    document: {
      readyState: 'complete',
      head: { appendChild() {} },
      createElement: () => ({ set textContent(_) {} }),
    },
    location: { reload: () => { reloads++; } },
    setTimeout, clearTimeout, Promise, JSON, Date, Math, String, Object, parseInt,
  });
  ctx.window.localStorage = localStorage;
  vm.runInContext(SRC, ctx);
  return { reloads: () => reloads };
}

console.log('\nnative.js — durability\n');

// 1 ── normal use mirrors everything outward
console.log('normal use');
const ls1 = makeLocalStorage({ theway_currentDay: '1', theway_welcomed: '1' });
boot(ls1);
await sleep(700);
ls1.setItem('theway_currentDay', '42');
ls1.setItem('theway_j:abc', JSON.stringify({ id: 'abc', hex: 43 }));
ls1.setItem('theway_j:def', JSON.stringify({ id: 'def', hex: 7 }));
await sleep(2600);
check('day mirrored', prefs.get('theway_currentDay'), '42');
check('backup written', files.has('journal-backup.json'), 'true');
check('entries backed', Object.keys(JSON.parse(files.get('journal-backup.json')).journal).length, 2);

// 2 ── iOS reclaims the webview data; everything comes back
console.log('\nafter data loss');
const ls2 = makeLocalStorage({});
const s2 = boot(ls2);
await sleep(900);
check('day restored', ls2.getItem('theway_currentDay'), '42');
check('journal back', ls2._keys('theway_j:').length, 2);
check('reloaded once', s2.reloads(), 1);

// 3 ── live data must never lose to a stale mirror
console.log('\nhealthy data');
const ls3 = makeLocalStorage({ theway_currentDay: '99', 'theway_j:x': '{"id":"x"}' });
const s3 = boot(ls3);
await sleep(900);
check('day preserved', ls3.getItem('theway_currentDay'), '99');
check('no reload', s3.reloads(), 0);

// 4 ── a deliberate deletion must not be resurrected by the backup
console.log('\ndeliberate deletion');
const ls4 = makeLocalStorage({ theway_currentDay: '42', 'theway_j:abc': '{}', 'theway_j:def': '{}' });
boot(ls4);
await sleep(700);
ls4.removeItem('theway_j:abc');
ls4.removeItem('theway_j:def');
await sleep(2600);
check('backup emptied', Object.keys(JSON.parse(files.get('journal-backup.json')).journal).length, 0);
const ls5 = makeLocalStorage({ theway_currentDay: '42' });
boot(ls5);
await sleep(900);
check('stayed deleted', ls5._keys('theway_j:').length, 0);

console.log(failures === 0 ? '\n✓ all durability checks passed\n' : `\n✗ ${failures} check(s) failed\n`);
process.exit(failures === 0 ? 0 : 1);
