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
 * Two: the lesson follows the calendar. index.html keeps an anchor — lesson L
 * on date D — and the day turns at the reminder time. Each reminder fires at
 * that moment and names the lesson that begins that morning. Staying moves
 * the anchor; the reminders must follow it, and must never wrap past 365.
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

async function run({ index, at, now, anchor, prefs = {} }) {
  let captured = null;
  let onAction = null;
  const store = new Map([
    ['theway_currentDay', String(index)],
    ['theway_remind_on', '1'],
    ['theway_remind_at', at],
  ]);
  if (anchor) {
    store.set('theway_anchorDay', String(anchor[0]));
    store.set('theway_anchorDate', anchor[1]);
    store.set('theway_anchorAt', String(anchor[2] || 1));
  }
  const localStorage = {
    get length() { return store.size; },
    key: (i) => [...store.keys()][i] ?? null,
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
  };
  const pref = new Map(Object.entries(prefs));

  const Plugins = {
    LocalNotifications: {
      addListener: (name, fn) => { if (name === 'localNotificationActionPerformed') onAction = fn; return Promise.resolve({ remove() {} }); },
      registerActionTypes: () => Promise.resolve(),
      getPending: () => Promise.resolve({ notifications: [] }),
      cancel: () => Promise.resolve(),
      requestPermissions: () => Promise.resolve({ display: 'granted' }),
      schedule: ({ notifications }) => { captured = notifications; return Promise.resolve(); },
    },
    Preferences: {
      get: ({ key }) => Promise.resolve({ value: pref.has(key) ? pref.get(key) : null }),
      set: ({ key, value }) => { pref.set(key, value); return Promise.resolve(); },
      remove: ({ key }) => { pref.delete(key); return Promise.resolve(); },
    },
  };

  const win = { Capacitor: { isNativePlatform: () => true, Plugins }, addEventListener() {}, dispatchEvent() {}, React: undefined };
  const ctx = vm.createContext({
    window: win, localStorage, LESSONS,
    navigator: {}, console: { log() {} },
    document: { readyState: 'complete', head: { appendChild() {} }, createElement: () => ({ set textContent(_) {} }) },
    location: { reload() {} },
    setTimeout, clearTimeout, Promise, JSON, Math, String, Object, parseInt, Event: class {},
    Date: frozenDate(now.getTime()),
  });
  ctx.window.localStorage = localStorage;
  vm.runInContext(SRC, ctx);
  await sleep(900);
  return { n: captured || [], store, pref, act: async (ev) => { onAction(ev); await sleep(200); return captured || []; } };
}

// Thursday 6 August 2026, 10:00 local.
const NOW = new Date(2026, 7, 6, 10, 0, 0);
const dayOf = (d) => new Date(d).getDate();
let r, n;

console.log('\nnative.js — reminder scheduling\n');

// Before the app has written an anchor, the reminders name where they are.
// Index 0 is lesson 1 — not day 0.
console.log('no anchor yet, fresh install');
n = (await run({ index: 0, at: '20:00', now: NOW })).n;
check('title', n[0].title, 'Lesson 1');
check('body', n[0].body, 'L1');
check('first fires 6th', dayOf(n[0].schedule.at), 6);
check('second fires 7th', dayOf(n[1].schedule.at), 7);

// Index 5 is lesson 6. This is the mapping that was silently wrong.
console.log('\nno anchor yet, index 5 = lesson 6');
n = (await run({ index: 5, at: '20:00', now: NOW })).n;
check('title', n[0].title, 'Lesson 6');
check('body', n[0].body, 'L6');

// The calendar: one lesson a day from the anchor.
console.log('\nfollows the calendar (lesson 6 on the 6th, reminder 20:00)');
n = (await run({ index: 5, at: '20:00', now: NOW, anchor: [6, '2026-08-06'] })).n;
check('6th names', n[0].title, 'Lesson 6');
check('7th names', n[1].title, 'Lesson 7');
check('day 30 of horizon', n[29].title, 'Lesson 35');
check('carries its lesson', n[1].extra.day, 7);
check('carries its time', n[1].extra.at, new Date(n[1].schedule.at).getTime());
check('offers Stay', n[1].actionTypeId, 'TW_LESSON');

// The reminder time is when the day turns. It has passed today, so the first
// one is tomorrow morning, and names tomorrow's lesson.
console.log('\nreminder time already passed (07:00)');
n = (await run({ index: 5, at: '07:00', now: NOW, anchor: [6, '2026-08-06'] })).n;
check('first fires 7th', dayOf(n[0].schedule.at), 7);
check('names lesson 7', n[0].title, 'Lesson 7');

// Before the reminder time the day has not turned yet: at 06:00 on the 7th,
// it is still the 6th's lesson.
console.log('\nbefore the day turns (06:00, reminder 07:00)');
n = (await run({ index: 5, at: '07:00', now: new Date(2026, 7, 7, 6, 0), anchor: [6, '2026-08-06'] })).n;
check('first fires 7th', dayOf(n[0].schedule.at), 7);
check('names lesson 7', n[0].title, 'Lesson 7');

// Staying: the anchor is on tomorrow, so tomorrow names today's lesson again.
console.log('\nstaying with lesson 6 tomorrow');
n = (await run({ index: 5, at: '07:00', now: NOW, anchor: [6, '2026-08-07'] })).n;
check('7th names', n[0].title, 'Lesson 6');
check('8th names', n[1].title, 'Lesson 7');

// "Stay with yesterday's lesson" on a reminder announcing lesson 8.
console.log('\nStay tapped on a reminder');
r = await run({ index: 7, at: '07:00', now: new Date(2026, 7, 8, 7, 5), anchor: [6, '2026-08-06'] });
n = await r.act({ actionId: 'stay', notification: { extra: { day: 8 } } });
check('anchor lesson', r.store.get('theway_anchorDay'), 7);
check('anchor date', r.store.get('theway_anchorDate'), '2026-08-08');
check('tomorrow names', n[0].title, 'Lesson 8');

// A plain tap opens the lesson and moves nothing.
r = await run({ index: 7, at: '07:00', now: new Date(2026, 7, 8, 7, 5), anchor: [6, '2026-08-06'] });
await r.act({ actionId: 'tap', notification: { extra: { day: 8 } } });
check('tap moves nothing', r.store.get('theway_anchorDay'), 6);

// Stay tapped on the widget arrives through Preferences; the newer one wins.
console.log('\nStay tapped on the widget');
r = await run({ index: 5, at: '07:00', now: NOW, anchor: [6, '2026-08-06', 100],
  prefs: { widget_anchor_day: '6', widget_anchor_date: '2026-08-07', widget_anchor_at: '200' } });
check('adopted', r.store.get('theway_anchorDate'), '2026-08-07');
check('7th names', r.n[0].title, 'Lesson 6');
r = await run({ index: 5, at: '07:00', now: NOW, anchor: [6, '2026-08-06', 300],
  prefs: { widget_anchor_day: '6', widget_anchor_date: '2026-08-07', widget_anchor_at: '200' } });
check('older one ignored', r.store.get('theway_anchorDate'), '2026-08-06');
check('widget told', r.pref.get('widget_anchor_date'), '2026-08-06');
check('widget day', r.pref.get('widget_day'), 6);

// The last lesson must not wrap around to the start of the year.
console.log('\nend of the year');
n = (await run({ index: 359, at: '20:00', now: NOW, anchor: [360, '2026-08-06'] })).n;
check('5 days on', n[5].title, 'Lesson 365');
check('no wraparound', n.slice(5).every((x) => x.title === 'Lesson 365'), 'true');

// An index past the end of the data must schedule nothing, not crash.
console.log('\nindex past the end of the year');
n = (await run({ index: 400, at: '20:00', now: NOW })).n;
check('nothing scheduled', n.length, 0);

console.log('\nhorizon');
n = (await run({ index: 0, at: '20:00', now: NOW, anchor: [1, '2026-08-06'] })).n;
check('count', n.length, 60);
check('under iOS cap of 64', n.length <= 64, 'true');
check('ids unique', new Set(n.map((x) => x.id)).size, 60);
check('lesson 1 has no Stay', n[0].actionTypeId, 'undefined');
const dates = n.map((x) => new Date(x.schedule.at).getTime());
const spacedByADay = dates.every((t, i) => i === 0 || Math.round((t - dates[i - 1]) / 86400000) === 1);
check('one day apart', spacedByADay, 'true');

console.log(failures === 0 ? '\n✓ all scheduling checks passed\n' : `\n✗ ${failures} check(s) failed\n`);
process.exit(failures === 0 ? 0 : 1);
