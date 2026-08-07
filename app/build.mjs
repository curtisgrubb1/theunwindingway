#!/usr/bin/env node
/**
 * The Way — iOS bundle build
 *
 * Takes the canonical ../index.html as the single source of truth and emits an
 * offline-complete www/ directory for Capacitor.
 *
 * Nothing about the app's content or logic is forked. Every change is a narrow,
 * asserted transform applied at build time, so the website and the iOS app can
 * never drift apart.
 *
 *   node build.mjs
 */

import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..');
const WWW = join(HERE, 'www');
const NM = join(HERE, 'node_modules');

// ── transform harness ────────────────────────────────────────────────────────
// Every transform must match exactly the number of times it expects. If the
// source app changes shape, the build fails loudly instead of silently shipping
// a half-patched bundle.

let applied = [];

function transform(html, { name, find, replace, expect = 1 }) {
  const parts = html.split(find);
  const hits = parts.length - 1;
  if (hits !== expect) {
    throw new Error(
      `Transform "${name}" matched ${hits} time(s), expected ${expect}.\n` +
      `The source index.html has changed shape. Anchor text:\n  ${String(find).slice(0, 160)}`
    );
  }
  applied.push(`${name} (${hits})`);
  return parts.join(replace);
}

// ── fonts ────────────────────────────────────────────────────────────────────

const FONT_SPEC = [
  { pkg: 'cormorant-garamond', family: 'Cormorant Garamond', weight: 300, style: 'normal' },
  { pkg: 'cormorant-garamond', family: 'Cormorant Garamond', weight: 400, style: 'normal' },
  { pkg: 'cormorant-garamond', family: 'Cormorant Garamond', weight: 500, style: 'normal' },
  { pkg: 'cormorant-garamond', family: 'Cormorant Garamond', weight: 300, style: 'italic' },
  { pkg: 'cormorant-garamond', family: 'Cormorant Garamond', weight: 400, style: 'italic' },
  { pkg: 'dm-sans', family: 'DM Sans', weight: 300, style: 'normal' },
  { pkg: 'dm-sans', family: 'DM Sans', weight: 400, style: 'normal' },
  { pkg: 'dm-sans', family: 'DM Sans', weight: 500, style: 'normal' },
];

// Two subsets share a family/weight/style, so each needs an explicit
// unicode-range. Without it the later @font-face silently wins outright and the
// other subset is never used. These are the standard Google Fonts ranges.
const SUBSET_RANGE = {
  latin:
    'U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,' +
    'U+0304,U+0308,U+0329,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,' +
    'U+2212,U+2215,U+FEFF,U+FFFD',
  'latin-ext':
    'U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,' +
    'U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,' +
    'U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF',
};

function buildFonts() {
  mkdirSync(join(WWW, 'fonts'), { recursive: true });
  const faces = [];
  for (const f of FONT_SPEC) {
    for (const subset of Object.keys(SUBSET_RANGE)) {
      const file = `${f.pkg}-${subset}-${f.weight}-${f.style}.woff2`;
      const src = join(NM, '@fontsource', f.pkg, 'files', file);
      if (!existsSync(src)) continue;
      copyFileSync(src, join(WWW, 'fonts', file));
      faces.push(
        `@font-face{font-family:'${f.family}';font-style:${f.style};font-weight:${f.weight};` +
        `font-display:swap;src:url('fonts/${file}') format('woff2');` +
        `unicode-range:${SUBSET_RANGE[subset]};}`
      );
    }
  }
  if (!faces.length) throw new Error('No font files found. Run: npm install');
  console.log(`  fonts: ${faces.length} faces bundled`);
  return faces.join('\n');
}

// ── vendor ───────────────────────────────────────────────────────────────────

function buildVendor() {
  mkdirSync(join(WWW, 'vendor'), { recursive: true });
  const pairs = [
    ['react/umd/react.production.min.js', 'react.production.min.js'],
    ['react-dom/umd/react-dom.production.min.js', 'react-dom.production.min.js'],
  ];
  for (const [from, to] of pairs) {
    const src = join(NM, from);
    if (!existsSync(src)) throw new Error(`Missing ${from}. Run: npm install`);
    copyFileSync(src, join(WWW, 'vendor', to));
  }
  console.log('  vendor: react + react-dom bundled locally');
}

// ── static assets ────────────────────────────────────────────────────────────

const STATIC = [
  'favicon.ico', 'favicon.svg', 'favicon-16.png', 'favicon-32.png', 'favicon-96.png',
  'apple-touch-icon.png', 'icon-512.png',
  'compass.png', // watermark behind the share card
  'icons/icon-192.png', 'icons/icon-512.png',
  'icons/icon-192-maskable.png', 'icons/icon-512-maskable.png',
];

function copyStatic() {
  let n = 0;
  for (const rel of STATIC) {
    const src = join(REPO, rel);
    if (!existsSync(src)) continue;
    const dest = join(WWW, rel);
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(src, dest);
    n++;
  }
  console.log(`  static: ${n} assets copied`);
}

// ── main ─────────────────────────────────────────────────────────────────────

console.log('\nThe Way — building iOS bundle\n');

if (existsSync(WWW)) {
  try {
    rmSync(WWW, { recursive: true, force: true });
  } catch (e) {
    console.log('  note: could not fully clear www/, overwriting in place');
  }
}
mkdirSync(WWW, { recursive: true });

let html = readFileSync(join(REPO, 'index.html'), 'utf8');
const sourceBytes = html.length;

buildVendor();
const fontFaces = buildFonts();
copyStatic();

// 1. React from local vendor instead of unpkg CDN.
//    Guideline 2.5.2: the app must be self-contained and must not fetch code at runtime.
html = transform(html, {
  name: 'react-local',
  find: '<script src="https://unpkg.com/react@18/umd/react.production.min.js" crossorigin></script>\n' +
        '<script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js" crossorigin></script>',
  replace: '<script src="vendor/react.production.min.js"></script>\n' +
           '<script src="vendor/react-dom.production.min.js"></script>\n' +
           '<script src="native.js"></script>',
});

// 2. Fonts from the bundle instead of Google Fonts.
//    Also removes a third-party network call, which keeps the privacy label clean.
html = transform(html, {
  name: 'fonts-local',
  find: "const FONTS = `@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,500;1,300;1,400&family=DM+Sans:wght@300;400;500&display=swap');`;",
  replace: 'const FONTS = `' + fontFaces + '`;',
});

// 3. Service worker: meaningless under the capacitor:// scheme and a source of
//    stale-asset bugs in a native shell. Native bundle is already offline-complete.
html = transform(html, {
  name: 'sw-disable',
  find: "if ('serviceWorker' in navigator) {                 \n" +
        "  navigator.serviceWorker.register('/sw.js');       \n" +
        "}",
  replace: '/* service worker intentionally not registered in the native build */',
});

// 4. Haptics: one tap as each of the six lines resolves.
html = transform(html, {
  name: 'haptic-line',
  find: '          built = [...built, allLines[i]];\n          setLines([...built]);',
  replace: '          built = [...built, allLines[i]];\n' +
           '          window.__twHaptic && window.__twHaptic("line");\n' +
           '          setLines([...built]);',
});

// 5. Haptics: a heavier note when the reading resolves.
html = transform(html, {
  name: 'haptic-reading',
  find: '            saveJournal(r1, r2, ci, built);\n            go("reading");',
  replace: '            saveJournal(r1, r2, ci, built);\n' +
           '            window.__twHaptic && window.__twHaptic("reading");\n' +
           '            go("reading");',
});

// 6. Mount point for the daily reminder control on the About screen.
//    Renders nothing on the web; renders the toggle only in the native app.
html = transform(html, {
  name: 'reminder-mount',
  find: '}, "curtis@curtisgrubb.org"), ',
  replace: '}, "curtis@curtisgrubb.org"), window.__twReminderEl ? window.__twReminderEl() : null, ',
});

// 7. Tag the build. Pinch-zoom is deliberately LEFT ENABLED — it is the only
//    magnification an iOS webview offers, so switching it off would remove a
//    real accessibility affordance. Involuntary zoom is prevented instead by
//    keeping every input at 16px or larger, the threshold below which iOS
//    zooms automatically on focus.
html = transform(html, {
  name: 'viewport-native',
  find: '<meta name="viewport"',
  replace: '<meta name="theway-build" content="ios"><meta name="viewport"',
});

// 8. Expose the navigation function so a tapped reminder can land on the
//    practice rather than wherever the app happened to be. `go` is defined
//    directly above this anchor. Assignment is guarded so the web build is
//    untouched — __twShareCtx is only ever defined by the native layer.
html = transform(html, {
  name: 'nav-bridge',
  find: '  const showToast = msg => {\n' +
        '    setToast(msg);\n' +
        '    setTimeout(() => setToast(null), 2000);\n' +
        '  };',
  replace: '  const showToast = msg => {\n' +
           '    setToast(msg);\n' +
           '    setTimeout(() => setToast(null), 2000);\n' +
           '  };\n' +
           '  if (window.__twShareCtx !== undefined) window.__twGo = go;',
});

// 9. Capture the reading being shared.
//    Both share buttons — the journal entry and the live reading — build their
//    text through this one function, so wrapping it here catches both and any
//    future caller, without touching either call site.
html = transform(html, {
  name: 'share-context',
  find: 'function buildReadingShareText(h1, chg, h2) {\n  if (!h1) return "";',
  replace: 'function buildReadingShareText(h1, chg, h2) {\n' +
           '  if (window.__twShareCtx !== undefined) window.__twShareCtx = { h1: h1, chg: chg, h2: h2 };\n' +
           '  if (!h1) return "";',
});

// 10. Strip web-only SEO and social metadata. None of it is ever fetched, but a
//    native bundle that references no external host at all is easier to defend
//    in review and keeps the verification below honest.
{
  const before = html.length;
  html = html
    .replace(/<link rel="canonical"[^>]*>\s*/gi, '')
    .replace(/<meta property="og:[^"]*"[^>]*>\s*/gi, '')
    .replace(/<meta name="twitter:[^"]*"[^>]*>\s*/gi, '')
    .replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>\s*/gi, '');
  applied.push(`seo-strip (${before - html.length} bytes)`);
}

writeFileSync(join(WWW, 'index.html'), html);
copyFileSync(join(HERE, 'src', 'native.js'), join(WWW, 'native.js'));

console.log(`\n  transforms: ${applied.join(', ')}`);
console.log(`  index.html: ${(sourceBytes / 1024 / 1024).toFixed(2)} MB in, ${(html.length / 1024 / 1024).toFixed(2)} MB out`);

// ── verification ─────────────────────────────────────────────────────────────

const remote = [...html.matchAll(/(?:src|href)\s*=\s*["']https?:\/\/[^"']+/gi)].map(m => m[0]);
const cssRemote = [...html.matchAll(/url\(['"]?https?:\/\/[^)'"]+/gi)].map(m => m[0]);
const runtimeRemote = [...remote, ...cssRemote];

if (runtimeRemote.length) {
  console.log('\n  ⚠ remote references still present:');
  runtimeRemote.forEach(r => console.log(`     ${r.slice(0, 100)}`));
  process.exitCode = 1;
} else {
  console.log('\n  ✓ zero remote runtime dependencies — bundle is offline-complete');
}

console.log('\nNext:  npx cap sync ios  &&  npx cap open ios\n');
