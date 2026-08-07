/**
 * Reminder scheduling tests for native.js
 *
 * The trap here is that `theway_currentDay` is a ZERO-BASED INDEX into LESSONS,
 * not a day number. The app reads it as LESSONS[day] and writes setDay(n - 1),
 * so a fresh install stores 0 and means lesson 1. Treating it as a day number
 * sends the wrong lesson every single day, quietly.
 *
 * The second trap is the calendar: if today's reminder time has already passed,
 * the first notification lands tomorrow, which is the NEXT lesson.
 *
 * Boots the real native.js against mocked plugins and a frozen clock.
 *
 *   npm run test:schedule
 */

import vm from 'node:vm';
import fs from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SRC = fs.readFileSync(join(HERE, '..', 'src', 'native.js'), 'utf8');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const LESSONS = Array.from({ length: 365 }, (_, i) => ({ day: i + 1, title: 'L' + (i + 1) }));

let failures = 0;
function check(label, actual, expected) {
  const ok = String(actual) === String(expected);
  if (!ok) failures++;
  console.log(`  ${label.padEnd(22)}: ${String(actual).padEnd(22)} ${ok ? '✓' : `✗ expected ${expected}`}`);
}

// A frozen clock, so "has today's time passed?" is deterministic.
function frozenDate(nowMs) {
  return class extends Date {
    constructor(...args) {
      if (args.length === 0) super(nowMs);
      else super(...args);
    }
    static now() { return nowMs; }
  };
}

async function run({ index, at, now }) {
  let captured = null;
  const store = new Map([
    ['theway_currentDay', String(index)],
    ['theway_remind_on', '1'],
    ['theway_remind_at', at],
  ]);
  const localStorage = {
    get length() { return store.size; },
    key: (i) => [...store.keys()][i] ?? null,
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
  };

  const Plugins = {
    LocalNotifications: {
      getPending: () => Promise.resolve({ notifications: [] }),
      cancel: () => Promise.resolve(),
      requestPermissions: () => Promise.resolve({ display: 'granted' }),
      schedule: ({ notifications }) => { captured = notifications; return Promise.resolve(); },
    },
  };

  const win = { Capacitor: { isNativePlatform: () => true, Plugins }, addEventListener() {}, React: undefined };
  const ctx = vm.createContext({
    window: win, localStorage, LESSONS,
    navigator: {}, console: { log() {} },
    document: { readyState: 'complete', head: { appendChild() {} }, createElement: () => ({ set textContent(_) {} }) },
    location: { reload() {} },
    setTimeout, clearTimeout, Promise, JSON, Math, String, Object, parseInt,
    Date: frozenDate(now.getTime()),
  });
  ctx.window.localStorage = localStorage;
  vm.runInContext(SRC, ctx);
  await sleep(900);
  return captured || [];
}

// Thursday 6 August 2026, 10:00 local.
const NOW = new Date(2026, 7, 6, 10, 0, 0);
const dayOf = (d) => new Date(d).getDate();

console.log('\nnative.js — reminder scheduling\n');

// A fresh install stores index 0, which means lesson 1 — not day 0.
console.log('fresh install, reminder later today (20:00)');
let n = await run({ index: 0, at: '20:00', now: NOW });
check('first title', n[0].title, 'Day 1');
check('first body', n[0].body, 'L1');
check('fires on the 6th', dayOf(n[0].schedule.at), 6);
check('second title', n[1].title, 'Day 2');
check('second on the 7th', dayOf(n[1].schedule.at), 7);

// Time already passed, so the first reminder is tomorrow — the next lesson.
console.log('\nfresh install, reminder already passed (07:00)');
n = await run({ index: 0, at: '07:00', now: NOW });
check('first title', n[0].title, 'Day 2');
check('first body', n[0].body, 'L2');
check('fires on the 7th', dayOf(n[0].schedule.at), 7);

// Index 5 is lesson 6. This is the case that was silently wrong.
console.log('\nmid-practice, index 5 = lesson 6');
n = await run({ index: 5, at: '20:00', now: NOW });
check('first title', n[0].title, 'Day 6');
check('first body', n[0].body, 'L6');
check('tenth title', n[9].title, 'Day 15');

// The year ends; it must not wrap or pad.
console.log('\nnear the end of the year, index 360 = lesson 361');
n = await run({ index: 360, at: '20:00', now: NOW });
check('count', n.length, 5);
check('first title', n[0].title, 'Day 361');
check('last title', n[n.length - 1].title, 'Day 365');

// iOS only holds 64 pending notifications; the horizon must stay under it.
console.log('\nhorizon');
n = await run({ index: 0, at: '20:00', now: NOW });
check('count', n.length, 60);
check('under iOS cap of 64', n.length <= 64, 'true');
check('ids unique', new Set(n.map((x) => x.id)).size, n.length);
const consecutive = n.every((x, i) => i === 0 || x.title === 'Day ' + (i + 1));
check('days consecutive', consecutive, 'true');

console.log(failures === 0 ? '\n✓ all scheduling checks passed\n' : `\n✗ ${failures} check(s) failed\n`);
process.exit(failures === 0 ? 0 : 1);
