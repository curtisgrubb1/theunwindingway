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

  if (P.Share) {
    navigator.share = function (data) {
      return P.Share.share({
        title: data && data.title,
        text: data && data.text,
        dialogTitle: 'Share',
      });
    };
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

  function lessonFor(day) {
    var L = window.LESSONS;
    if (!L || !L.length) return null;
    var i = Math.max(1, Math.min(L.length, day || 1)) - 1;
    return L[i] || null;
  }

  function currentDay() {
    var d = parseInt(localStorage.getItem('theway_currentDay') || '1', 10);
    return isNaN(d) ? 1 : d;
  }

  function syncWidget() {
    try {
      if (!P.Preferences) return;
      var day = currentDay();
      var lesson = lessonFor(day);
      if (!lesson) return;
      P.Preferences.set({ key: 'widget_day', value: String(day) });
      P.Preferences.set({ key: 'widget_title', value: String(lesson.title || '') });
      if (P.WidgetsBridge) P.WidgetsBridge.reloadAllTimelines();
    } catch (e) {}
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
    if (!P.LocalNotifications) return Promise.resolve();
    return clearScheduled().then(function () {
      if (!remindOn()) return;

      var at = remindAt().split(':');
      var hh = parseInt(at[0], 10) || 7;
      var mm = parseInt(at[1], 10) || 0;

      var day = currentDay();
      var now = new Date();
      var first = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hh, mm, 0, 0);
      if (first <= now) first.setDate(first.getDate() + 1);

      var items = [];
      for (var i = 0; i < HORIZON; i++) {
        var when = new Date(first.getTime());
        when.setDate(when.getDate() + i);
        var lesson = lessonFor(day + i);
        if (!lesson) break;
        items.push({
          id: 1000 + i,
          title: 'Day ' + (day + i),
          body: lesson.title,
          schedule: { at: when, allowWhileIdle: true },
        });
      }
      if (!items.length) return;
      return P.LocalNotifications.schedule({ notifications: items });
    }).catch(function () {});
  }

  function enable() {
    if (!P.LocalNotifications) return Promise.resolve(false);
    return P.LocalNotifications.requestPermissions().then(function (res) {
      var ok = res && (res.display === 'granted' || res.display === 'prompt-with-rationale');
      if (!ok) return false;
      localStorage.setItem(PREF_ON, '1');
      return schedule().then(function () { return true; });
    }).catch(function () { return false; });
  }

  function disable() {
    localStorage.setItem(PREF_ON, '0');
    return clearScheduled();
  }

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

  // ── lifecycle ──────────────────────────────────────────────────────────────

  function refresh() { syncWidget(); if (remindOn()) schedule(); }

  if (document.readyState === 'complete') setTimeout(refresh, 600);
  else window.addEventListener('load', function () { setTimeout(refresh, 600); });

  try {
    if (P.App) P.App.addListener('appStateChange', function (st) { if (st && st.isActive) refresh(); });
  } catch (e) {}

  // The app writes progress straight to localStorage; catch changes made in
  // this tab, which the storage event does not fire for.
  var _set = localStorage.setItem.bind(localStorage);
  localStorage.setItem = function (k, v) {
    _set(k, v);
    if (k === 'theway_currentDay') { syncWidget(); if (remindOn()) schedule(); }
  };
})();
