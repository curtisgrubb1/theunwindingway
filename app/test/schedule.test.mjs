/**
 * Reminder scheduling tests for native.js
 *
 * Two traps live here.
 *
 * One: `theway_currentDay` is a ZERO-BASED INDEX into LESSONS, not a day
 * number. The app reads LESSONS[day] and writes setDay(n - 1), so a fresh
 * install stores 0 and means lesson 1. Treating it as a day number sends the
 * wrong lesson every day, quietly.
 *
 * Two: reminders must NOT project forward. The workbook gives one lesson a day,
 * but people sit with a lesson for several days. Every scheduled notification
 * names the lesson they are on right now and claims nothing about the future;
 * rescheduling on app open keeps it true.
 *
 * Boots the real native.js against mocked plugins and a frozen clock.
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

const LESSONS = Array.from({ length: 365 }, (_, i) => ({ day: i + 1, title: 'L' + (i + 1) }));

let failures = 0;
function check(label, actual, expected) {
  const ok = String(actual) === String(expected);
  if (!ok) failures++;
  console.log(`  ${label.padEnd(24)}: ${String(actual).padEnd(10)} ${ok ? '✓' : `✗ expected ${expected}`}`);
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
      addListener: () => Promise.resolve({ remove() {} }),
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
check('title', n[0].title, 'Day 1');
check('body', n[0].body, 'L1');
check('first fires 6th', dayOf(n[0].schedule.at), 6);
check('second fires 7th', dayOf(n[1].schedule.at), 7);

// Time already passed today, so the first one lands tomorrow — but it still
// names the lesson they are on, because they may not have advanced.
console.log('\nreminder time already passed (07:00)');
n = await run({ index: 0, at: '07:00', now: NOW });
check('title', n[0].title, 'Day 1');
check('first fires 7th', dayOf(n[0].schedule.at), 7);

// Index 5 is lesson 6. This is the mapping that was silently wrong.
console.log('\nmid-practice, index 5 = lesson 6');
n = await run({ index: 5, at: '20:00', now: NOW });
check('title', n[0].title, 'Day 6');
check('body', n[0].body, 'L6');

// The behavioural contract: no projection into the future.
console.log('\ndoes not project forward');
n = await run({ index: 5, at: '20:00', now: NOW });
check('day 1 of horizon', n[0].title, 'Day 6');
check('day 30 of horizon', n[29].title, 'Day 6');
check('day 60 of horizon', n[59].title, 'Day 6');
check('all identical', new Set(n.map((x) => x.title)).size, 1);

// The last lesson must not wrap around to the start of the year.
console.log('\nlast lesson, index 364 = lesson 365');
n = await run({ index: 364, at: '20:00', now: NOW });
check('title', n[0].title, 'Day 365');
check('no wraparound', n.every((x) => x.title === 'Day 365'), 'true');

// An index past the end of the data must schedule nothing, not crash.
console.log('\nindex past the end of the year');
n = await run({ index: 400, at: '20:00', now: NOW });
check('nothing scheduled', n.length, 0);

console.log('\nhorizon');
n = await run({ index: 0, at: '20:00', now: NOW });
check('count', n.length, 60);
check('under iOS cap of 64', n.length <= 64, 'true');
check('ids unique', new Set(n.map((x) => x.id)).size, 60);
const dates = n.map((x) => new Date(x.schedule.at).getTime());
const spacedByADay = dates.every((t, i) => i === 0 || Math.round((t - dates[i - 1]) / 86400000) === 1);
check('one day apart', spacedByADay, 'true');

console.log(failures === 0 ? '\n✓ all scheduling checks passed\n' : `\n✗ ${failures} check(s) failed\n`);
process.exit(failures === 0 ? 0 : 1);
