/**
 * The Way — native layer
 *
 * Loaded only in the iOS bundle. Every entry point is a no-op when Capacitor
 * isn't present, so this file is harmless if it ever ends up on the web build.
 *
 * Talks to Capacitor through window.Capacitor.Plugins, which the native bridge
 * populates at runtime. No bundler, no imports — the app stays a single-file
 * script the way it has always been.
 */
(function () {
  'use strict';

  var Cap = window.Capacitor;
  var native = !!(Cap && Cap.isNativePlatform && Cap.isNativePlatform());
  if (!native) return;

  var P = Cap.Plugins || {};
  var GOLD = '#c4956a';
  var SERIF = "'Cormorant Garamond',serif";
  var SANS = "'DM Sans',sans-serif";

  // Everything below fails soft so a broken native path can never take the app
  // down. That makes silent no-ops the default failure mode, so say something.
  // Visible in Safari ▸ Develop ▸ Simulator ▸ index.html.
  function diag(msg, err) {
    try { console.log('[The Way] ' + msg, err === undefined ? '' : err); } catch (e) {}
  }

  // ── haptics ────────────────────────────────────────────────────────────────
  // One light tap as each of the six lines resolves; a heavier note when the
  // whole reading lands. The cast becomes something you feel, not just watch.

  window.__twHaptic = function (kind) {
    try {
      if (!P.Haptics) return;
      if (kind === 'line') P.Haptics.impact({ style: 'LIGHT' });
      else if (kind === 'reading') P.Haptics.notification({ type: 'SUCCESS' });
    } catch (e) {}
  };

  // ── share ──────────────────────────────────────────────────────────────────
  // WKWebView has no Web Share API. The app already calls navigator.share with a
  // clipboard fallback, so shimming it here means the existing code just works.

  // Set to null so the wrapper around buildReadingShareText knows to populate it.
  // Left undefined on the web build, where that assignment is skipped entirely.
  window.__twShareCtx = null;

  var INK = '#0e0e0c';
  var CREAM = '#e9dfcb';

  // The six lines of a hexagram, bottom first, derived from its King Wen number
  // by inverting the lookup table. Works from the journal too, where the reading
  // object carries a number but no trigram data.
  function hexLines(num) {
    try {
      var n = parseInt(num, 10);
      for (var lBin in TRI_IDX) {
        for (var uBin in TRI_IDX) {
          if (KW[TRI_IDX[lBin]][TRI_IDX[uBin]] === n) return (lBin + uBin).split('');
        }
      }
    } catch (e) {}
    return null;
  }

  // Hexagram names all take the form
  //   "Breakthrough (Resoluteness) · Guài  (☱ over ☰ — Lake over Heaven)"
  // which is far too long to set on one line. Split it into its three parts so
  // the card can typeset them, and drop the trigram glyphs — the bundled fonts
  // are Latin-only and those characters would render as empty boxes.
  function parseHexName(raw) {
    var s = String(raw || '');
    var out = { title: s, pinyin: '', gloss: '' };
    var dot = s.indexOf(' · ');
    if (dot < 0) return out;
    out.title = s.slice(0, dot).trim();
    var rest = s.slice(dot + 3).trim();
    var op = rest.indexOf('(');
    if (op < 0) { out.pinyin = rest; return out; }
    out.pinyin = rest.slice(0, op).trim();
    var inside = rest.slice(op + 1).replace(/\)\s*$/, '');
    var dash = inside.indexOf('—');
    out.gloss = (dash >= 0 ? inside.slice(dash + 1) : inside).trim();
    return out;
  }

  // Draw the reading as a card. Changing lines are drawn in gold against the
  // cream of the still ones — the traditional marks say the same thing with
  // more noise.
  function drawCard(ctx3) {
    var W = 1080, H = 1350;
    var c = document.createElement('canvas');
    c.width = W; c.height = H;
    var g = c.getContext('2d');

    g.fillStyle = INK;
    g.fillRect(0, 0, W, H);

    var h1 = ctx3.h1 || {};
    var chg = ctx3.chg || [];
    var h2 = ctx3.h2;
    var lines = hexLines(h1.num);
    if (!lines) return null;

    var MAXW = 900; // 90px of air either side

    function center(text, y, font, color, spacing) {
      if (!text) return;
      g.font = font;
      g.fillStyle = color;
      g.textAlign = 'center';
      try { g.letterSpacing = (spacing || 0) + 'px'; } catch (e) {}
      g.fillText(text, W / 2, y);
      try { g.letterSpacing = '0px'; } catch (e) {}
    }

    // Shrink until it fits rather than letting it run off the edge. Titles
    // range from "Peace" to "The Taming Power of the Great".
    function fitted(text, startPx, minPx, tmpl) {
      var px = startPx;
      while (px > minPx) {
        g.font = tmpl(px);
        if (g.measureText(text).width <= MAXW) break;
        px -= 2;
      }
      return tmpl(px);
    }

    var serif = function (px) { return '300 ' + px + 'px "Cormorant Garamond", serif'; };
    var serifI = function (px) { return 'italic 300 ' + px + 'px "Cormorant Garamond", serif'; };

    center('THE WAY', 150, '500 22px "DM Sans", sans-serif', 'rgba(196,149,106,.42)', 7);

    // Six lines, bottom-up, in the geometry of the app icon.
    var barW = 620, barH = 24, step = 74, gap = 120;
    var x0 = (W - barW) / 2, yTop = 300;
    for (var i = 0; i < 6; i++) {
      var y = yTop + (5 - i) * step;
      g.fillStyle = chg.indexOf(i) >= 0 ? GOLD : CREAM;
      if (lines[i] === '1') {
        g.fillRect(x0, y, barW, barH);                       // yang — unbroken
      } else {
        var seg = (barW - gap) / 2;                          // yin — broken
        g.fillRect(x0, y, seg, barH);
        g.fillRect(x0 + seg + gap, y, seg, barH);
      }
    }

    var n1 = parseHexName(h1.name);

    center('HEXAGRAM ' + h1.num, 800, '400 22px "DM Sans", sans-serif', 'rgba(196,149,106,.5)', 5);
    center(n1.title, 880, fitted(n1.title, 62, 30, serif), 'rgba(233,223,203,.92)');
    center(n1.pinyin, 945, serifI(34), 'rgba(196,149,106,.6)');
    center(n1.gloss ? n1.gloss.toUpperCase() : '', 1002,
      '400 17px "DM Sans", sans-serif', 'rgba(212,208,200,.28)', 4);

    if (h2 && h2.num) {
      var t2 = 'changing to ' + h2.num + ' · ' + parseHexName(h2.name).title;
      center(t2, 1090, fitted(t2, 32, 20, serifI), 'rgba(212,208,200,.4)');
    }

    center('theunwindingway.com', 1270, '400 18px "DM Sans", sans-serif', 'rgba(196,149,106,.25)', 3);

    return c.toDataURL('image/png');
  }

  function shareWithCard(data) {
    var payload = {
      title: data && data.title,
      text: data && data.text,
      dialogTitle: 'Share',
    };

    var ctx3 = window.__twShareCtx;
    if (!P.Filesystem || !ctx3 || !ctx3.h1) return P.Share.share(payload);

    // Canvas needs the bundled faces resolved before it can draw with them,
    // otherwise it silently falls back to a system serif.
    var ready = document.fonts && document.fonts.load
      ? Promise.all([
          document.fonts.load('300 62px "Cormorant Garamond"'),
          document.fonts.load('400 22px "DM Sans"'),
        ]).catch(function () {})
      : Promise.resolve();

    return ready
      .then(function () {
        var url = drawCard(ctx3);
        if (!url) throw new Error('card not drawn');
        return P.Filesystem.writeFile({
          path: 'reading-' + ctx3.h1.num + '.png',
          data: url.split(',')[1],
          directory: 'CACHE',
        });
      })
      .then(function () {
        return P.Filesystem.getUri({
          path: 'reading-' + ctx3.h1.num + '.png',
          directory: 'CACHE',
        });
      })
      .then(function (res) {
        payload.files = [res.uri];
        return P.Share.share(payload);
      })
      .catch(function (e) {
        diag('card share failed, falling back to text', e);
        return P.Share.share(payload);
      });
  }

  if (P.Share) {
    navigator.share = function (data) { return shareWithCard(data); };
  }

  // ── chrome ─────────────────────────────────────────────────────────────────

  try {
    if (P.StatusBar) P.StatusBar.setStyle({ style: 'DARK' });
    if (P.SplashScreen) setTimeout(function () { P.SplashScreen.hide(); }, 300);
  } catch (e) {}

  // Safe area: keep content clear of the notch and home indicator.
  var safe = document.createElement('style');
  safe.textContent =
    'body{padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom);' +
    'padding-left:env(safe-area-inset-left);padding-right:env(safe-area-inset-right);' +
    '-webkit-touch-callout:none;overscroll-behavior:none;}';
  document.head.appendChild(safe);

  // ── widget state ───────────────────────────────────────────────────────────
  // Mirror the current lesson into the shared App Group so the home screen
  // widget can read it. Preferences is configured with the group in
  // capacitor.config.json; on iOS these land in UserDefaults under
  // the "CapacitorStorage." prefix, which the Swift widget reads directly.

  // LESSONS is declared with `const` at the top level of a classic script. That
  // creates a global *lexical* binding, which is never exposed as a property of
  // window — so it must be read as a bare identifier. Reading window.LESSONS
  // returns undefined and silently breaks both the reminders and the widget.
  function allLessons() {
    try {
      return (typeof LESSONS !== 'undefined' && LESSONS && LESSONS.length) ? LESSONS : null;
    } catch (e) {
      return null; // still in the temporal dead zone
    }
  }

  // theway_currentDay is a ZERO-BASED INDEX into LESSONS, not a day number.
  // The app reads it as LESSONS[day] and writes it as setDay(n - 1), and a
  // fresh install stores 0, meaning lesson 1. Every lesson also carries its own
  // .day field, so read the number off the lesson rather than doing the
  // arithmetic a second time here and getting it wrong.
  function currentIndex() {
    var d = parseInt(localStorage.getItem('theway_currentDay') || '0', 10);
    return (isNaN(d) || d < 0) ? 0 : d;
  }

  function lessonAt(index) {
    var L = allLessons();
    if (!L) { diag('lesson data not reachable'); return null; }
    if (index < 0 || index >= L.length) return null;
    return L[index];
  }

  function syncWidget() {
    try {
      if (!P.Preferences) return;
      var lesson = lessonAt(currentIndex());
      if (!lesson) return;
      P.Preferences.set({ key: 'widget_day', value: String(lesson.day) });
      P.Preferences.set({ key: 'widget_title', value: String(lesson.title || '') });
      if (P.WidgetsBridge) P.WidgetsBridge.reloadAllTimelines();
      diag('widget state synced — day ' + lesson.day);
    } catch (e) { diag('widget sync failed', e); }
  }

  // ── daily reminder ─────────────────────────────────────────────────────────
  // Off unless asked for. Rather than one repeating alert, this schedules the
  // next 60 days individually so each notification carries that day's actual
  // lesson — and reschedules whenever the app opens.

  var PREF_ON = 'theway_remind_on';
  var PREF_AT = 'theway_remind_at'; // "HH:MM"
  var HORIZON = 60;

  function remindOn() { return localStorage.getItem(PREF_ON) === '1'; }
  function remindAt() { return localStorage.getItem(PREF_AT) || '07:00'; }

  function clearScheduled() {
    if (!P.LocalNotifications) return Promise.resolve();
    return P.LocalNotifications.getPending()
      .then(function (res) {
        var ids = (res && res.notifications) || [];
        if (!ids.length) return;
        return P.LocalNotifications.cancel({ notifications: ids });
      })
      .catch(function () {});
  }

  function schedule() {
    if (!P.LocalNotifications) {
      diag('LocalNotifications plugin not registered — did `npx cap sync ios` run?');
      return Promise.resolve();
    }
    return clearScheduled().then(function () {
      if (!remindOn()) return;

      var at = remindAt().split(':');
      var hh = parseInt(at[0], 10) || 7;
      var mm = parseInt(at[1], 10) || 0;

      var now = new Date();
      var first = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hh, mm, 0, 0);
      if (first <= now) first.setDate(first.getDate() + 1);

      // Every scheduled reminder names the lesson they are on right now, and
      // claims nothing about the future. The workbook gives one lesson a day,
      // but people sit with a lesson for several days, and predicting forward
      // would name a lesson they never reached. Rescheduling happens on every
      // app open and whenever the day changes — which is exactly when someone
      // advances — so this stays true without guessing.
      var lesson = lessonAt(currentIndex());
      if (!lesson) {
        diag('nothing scheduled — no lesson data available');
        return;
      }

      var items = [];
      for (var i = 0; i < HORIZON; i++) {
        var when = new Date(first.getTime());
        when.setDate(when.getDate() + i);
        items.push({
          id: 1000 + i,
          title: 'Day ' + lesson.day,
          body: lesson.title,
          schedule: { at: when, allowWhileIdle: true },
        });
      }
      return P.LocalNotifications.schedule({ notifications: items })
        .then(function () {
          diag('scheduled ' + items.length + ' reminders, first at ' + first.toLocaleString());
        })
        .catch(function (e) { diag('schedule failed', e); });
    }).catch(function (e) { diag('schedule failed', e); });
  }

  function enable() {
    if (!P.LocalNotifications) return Promise.resolve(false);
    return P.LocalNotifications.requestPermissions().then(function (res) {
      var ok = res && (res.display === 'granted' || res.display === 'prompt-with-rationale');
      if (!ok) { diag('notification permission not granted: ' + (res && res.display)); return false; }
      localStorage.setItem(PREF_ON, '1');
      return schedule().then(function () { return true; });
    }).catch(function (e) { diag('requestPermissions failed', e); return false; });
  }

  function disable() {
    localStorage.setItem(PREF_ON, '0');
    return clearScheduled();
  }

  // ── tapping a reminder ─────────────────────────────────────────────────────
  // Land on the practice, not on wherever the app was left. The listener is
  // registered before React mounts, so on a cold start __twGo does not exist
  // yet — wait for it rather than dropping the tap.

  function openLesson() {
    var tries = 0;
    (function attempt() {
      if (typeof window.__twGo === 'function') { window.__twGo('lesson'); return; }
      if (tries++ < 40) setTimeout(attempt, 100);
      else diag('could not open lesson — navigation bridge never appeared');
    })();
  }

  try {
    if (P.LocalNotifications) {
      P.LocalNotifications.addListener('localNotificationActionPerformed', openLesson);
    }
  } catch (e) { diag('notification tap listener failed', e); }

  // ── reminder control (About screen) ────────────────────────────────────────

  var R = window.React;

  function Reminder() {
    var s = R.useState(remindOn());
    var on = s[0], setOn = s[1];
    var t = R.useState(remindAt());
    var at = t[0], setAt = t[1];
    var b = R.useState(false);
    var busy = b[0], setBusy = b[1];

    var label = {
      fontFamily: SANS, fontSize: 11, letterSpacing: 1.5,
      color: 'rgba(196,149,106,.35)', textTransform: 'uppercase',
    };

    function toggle() {
      if (busy) return;
      setBusy(true);
      var next = !on;
      (next ? enable() : disable().then(function () { return false; }))
        .then(function (granted) {
          setOn(next ? !!granted : false);
          setBusy(false);
        });
    }

    function changeTime(e) {
      var v = e.target.value || '07:00';
      setAt(v);
      localStorage.setItem(PREF_AT, v);
      if (on) schedule();
    }

    return R.createElement(
      'div',
      { style: { marginTop: 48, paddingTop: 32, borderTop: '1px solid rgba(196,149,106,.12)' } },
      R.createElement('div', { style: label }, 'Daily reminder'),
      R.createElement(
        'button',
        {
          onClick: toggle,
          disabled: busy,
          style: {
            marginTop: 14, background: 'none', cursor: 'pointer',
            border: '1px solid ' + (on ? 'rgba(196,149,106,.45)' : 'rgba(196,149,106,.18)'),
            color: on ? GOLD : 'rgba(196,149,106,.4)',
            fontFamily: SANS, fontSize: 12, letterSpacing: 1.5,
            padding: '10px 22px', borderRadius: 2, transition: 'all .3s',
          },
        },
        busy ? '…' : on ? 'ON' : 'OFF'
      ),
      on &&
        R.createElement(
          'div',
          { style: { marginTop: 18 } },
          R.createElement('input', {
            type: 'time',
            value: at,
            onChange: changeTime,
            style: {
              background: 'none', border: 'none', color: GOLD,
              fontFamily: SERIF, fontSize: 22, fontWeight: 300,
              letterSpacing: 1, textAlign: 'center', outline: 'none',
            },
          })
        ),
      R.createElement(
        'p',
        {
          style: {
            marginTop: 16, fontFamily: SERIF, fontStyle: 'italic', fontSize: 13,
            fontWeight: 300, color: 'rgba(212,208,200,.32)', lineHeight: 1.7,
            maxWidth: 300, marginLeft: 'auto', marginRight: 'auto',
          },
        },
        on
          ? 'A single note each day. Nothing more.'
          : 'No reminder. The practice waits for you.'
      )
    );
  }

  window.__twReminderEl = function () {
    return R.createElement(Reminder);
  };

  // ── durability ─────────────────────────────────────────────────────────────
  // A year of practice lives in localStorage, which is the least durable store
  // iOS offers. It survives launches and app updates, but it is webview state
  // and the system is entitled to reclaim it. Losing someone's progress on day
  // 200 is a real harm, so everything is mirrored somewhere sturdier:
  //
  //   the current day, and whether they have been welcomed  →  Preferences (UserDefaults)
  //   the journal                                           →  a JSON file on disk
  //
  // The file lives in DATA, which is Library/NoCloud on iOS — deliberately not
  // backed up to iCloud, so "never transmitted anywhere" stays literally true.

  var MIRROR_KEYS = ['theway_currentDay', 'theway_welcomed'];
  var J_PREFIX = 'theway_j:';
  var BACKUP = 'journal-backup.json';

  var _set = localStorage.setItem.bind(localStorage);
  var _remove = localStorage.removeItem.bind(localStorage);
  var backupTimer = null;

  function journalEntries() {
    var out = {}, n = 0;
    for (var i = 0; i < localStorage.length; i++) {
      var k = localStorage.key(i);
      if (k && k.indexOf(J_PREFIX) === 0) { out[k] = localStorage.getItem(k); n++; }
    }
    return { entries: out, count: n };
  }

  function writeBackup() {
    if (!P.Filesystem) return;
    var j = journalEntries();
    P.Filesystem.writeFile({
      path: BACKUP,
      data: JSON.stringify({ v: 1, at: Date.now(), journal: j.entries }),
      directory: 'DATA',
      encoding: 'utf8',
    })
      .then(function () { diag('journal backed up — ' + j.count + ' entries'); })
      .catch(function (e) { diag('journal backup failed', e); });
  }

  // Journal writes can arrive in bursts; coalesce them.
  function scheduleBackup() {
    clearTimeout(backupTimer);
    backupTimer = setTimeout(writeBackup, 2000);
  }

  // Only ever restores into a gap. Anything already in localStorage wins —
  // this must never overwrite live state with something stale.
  function restore() {
    var restored = 0;
    var jobs = [];

    if (P.Preferences) {
      MIRROR_KEYS.forEach(function (k) {
        if (localStorage.getItem(k) !== null) return;
        jobs.push(
          P.Preferences.get({ key: k })
            .then(function (r) {
              if (r && r.value !== null && r.value !== undefined) {
                _set(k, r.value);
                restored++;
                diag('restored ' + k + ' = ' + r.value);
              }
            })
            .catch(function () {})
        );
      });
    }

    if (P.Filesystem && journalEntries().count === 0) {
      jobs.push(
        P.Filesystem.readFile({ path: BACKUP, directory: 'DATA', encoding: 'utf8' })
          .then(function (r) {
            var data = JSON.parse(r.data);
            var n = 0;
            for (var k in data.journal) { _set(k, data.journal[k]); n++; }
            if (n) { restored += n; diag('restored ' + n + ' journal entries'); }
          })
          .catch(function () {}) // no backup yet is the normal case
      );
    }

    return Promise.all(jobs).then(function () { return restored; });
  }

  // ── mirroring ──────────────────────────────────────────────────────────────
  // The app writes progress straight to localStorage, and the storage event
  // does not fire for changes made in the same document — so intercept.

  localStorage.setItem = function (k, v) {
    _set(k, v);
    try {
      if (MIRROR_KEYS.indexOf(k) >= 0 && P.Preferences) {
        P.Preferences.set({ key: k, value: String(v) });
      }
      if (k.indexOf(J_PREFIX) === 0) scheduleBackup();
      if (k === 'theway_currentDay') { syncWidget(); if (remindOn()) schedule(); }
    } catch (e) { diag('mirror failed for ' + k, e); }
  };

  localStorage.removeItem = function (k) {
    _remove(k);
    try {
      if (MIRROR_KEYS.indexOf(k) >= 0 && P.Preferences) P.Preferences.remove({ key: k });
      if (k.indexOf(J_PREFIX) === 0) scheduleBackup();
    } catch (e) { diag('mirror removal failed for ' + k, e); }
  };

  // ── lifecycle ──────────────────────────────────────────────────────────────

  function refresh() { syncWidget(); if (remindOn()) schedule(); }

  var reloaded = false;

  function start() {
    restore().then(function (restored) {
      // React has already read localStorage by now, so a restore has to be
      // followed by a reload to be visible. This is the exceptional path: it
      // only runs when data was actually lost, and cannot loop, because the
      // next pass finds localStorage populated and restores nothing.
      if (restored > 0 && !reloaded) {
        reloaded = true;
        diag('restored ' + restored + ' item(s) — reloading to apply');
        location.reload();
        return;
      }
      refresh();
      scheduleBackup(); // ensure a backup exists even with no writes this session
    });
  }

  if (document.readyState === 'complete') setTimeout(start, 600);
  else window.addEventListener('load', function () { setTimeout(start, 600); });

  try {
    if (P.App) {
      P.App.addListener('appStateChange', function (st) {
        if (st && st.isActive) refresh();
        else writeBackup(); // flush on the way to the background
      });
    }
  } catch (e) {}
})();
