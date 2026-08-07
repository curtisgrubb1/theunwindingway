# The Way — iOS

The website is the source of truth. `../index.html` is the app.

This folder does not contain a copy of The Way. It contains a build script that
takes `../index.html` and emits an offline-complete iOS bundle. Every change it
makes is a narrow, asserted transform — if the source app changes shape, the
build fails loudly rather than shipping a half-patched bundle.

**Never edit the app inside `www/`.** It is deleted and regenerated on every build.

---

## What the build does

| Transform | Why |
|---|---|
| React from `vendor/` instead of unpkg | Guideline 2.5.2 — the app may not fetch code at runtime |
| Fonts bundled locally instead of Google Fonts | Same, plus it removes a third-party network call and keeps the privacy label clean |
| Service worker not registered | Meaningless under `capacitor://`, and a source of stale-asset bugs |
| Haptic on each of the six lines | Guideline 4.2 — native capability |
| Haptic when the reading resolves | Same |
| Reminder control mounted on the About screen | Same |
| SEO / social metadata stripped | Never fetched, but a bundle referencing no external host at all is easier to defend |

Result: **zero remote runtime dependencies.** The app works in airplane mode.
The build verifies this and fails if any external reference survives.

---

## Durability

A year of practice lives in `localStorage`, which is the least durable store iOS
offers. It survives launches and app updates, but it is webview state and the
system is entitled to reclaim it. Losing someone's progress on day 200 is a real
harm, so `native.js` mirrors it:

- **current day, welcomed flag** → Preferences (`UserDefaults`)
- **the journal** → a JSON file in `DATA`, which is `Library/NoCloud` on iOS

`NoCloud` is deliberate: nothing goes to iCloud, so "never transmitted anywhere"
in the privacy statement stays literally true.

Restore only ever fills a gap — anything already in `localStorage` wins, so a
stale mirror can never overwrite live state. When a restore does happen the app
reloads once so React picks it up; it cannot loop, because the next pass finds
`localStorage` populated.

## `theway_currentDay` is an index, not a day

Worth knowing before touching anything that reads it. The app stores a
**zero-based index into `LESSONS`** — it reads `LESSONS[day]` and writes
`setDay(n - 1)`. A fresh install stores `0`, meaning lesson 1.

Treating it as a day number is silently wrong: index 5 is lesson 6, so every
reminder names the lesson before the one the practitioner is actually on. Read
the number off `lesson.day` rather than doing the arithmetic a second time.

---

## Tests

```bash
npm test
```

Both suites boot the real `native.js` against mocked Capacitor plugins. No iOS
required, no simulator, about two seconds.

**Durability** — normal mirroring, recovery after data loss, healthy data left
untouched, and a deliberate journal deletion not being resurrected.

**Scheduling** — the index-vs-day mapping above, and the contract that reminders
**never project forward**. Every scheduled notification names the lesson the
practitioner is on right now. The workbook gives one lesson a day, but people
sit with a lesson for several days, and guessing ahead would name a lesson they
never reached. Rescheduling happens on app open and whenever the day changes —
which is exactly when someone advances — so it stays true without predicting.
Also covers the end of the year not wrapping, and the horizon staying under the
iOS cap of 64 pending notifications.

Run them whenever `native.js` changes. Both cover code whose failure mode is
silent: wrong lesson, or lost year.

---

## One-time setup

Requires a Mac, Xcode 16+, Node 20+, and CocoaPods (`sudo gem install cocoapods`).

```bash
cd app
npm install
npm run build          # produces www/
npx cap add ios        # creates the Xcode project — run once, ever
npx cap sync ios
npx cap open ios
```

### In Xcode, once

1. **Signing** — select the App target ▸ Signing & Capabilities ▸ your Apple
   Developer team. Bundle ID is `com.curtisgrubb.theway` (change it in
   `capacitor.config.json` first if you want something else — changing it later
   is painful).
2. **Deployment target** — iOS 15.0 or higher.
3. **App Group** — Signing & Capabilities ▸ `+` ▸ App Groups ▸ add
   `group.com.curtisgrubb.theway`. This is how the widget reads your current day.
4. **Icons** — drag `ios-assets/AppIcon-1024.png` into `Assets.xcassets ▸ AppIcon`.
   Already 1024×1024, no alpha, square corners; Apple applies the rounding.
5. **Launch screen** — set the background to `#0e0e0c` so the cold start doesn't
   flash white before the app paints.

### The widget

1. File ▸ New ▸ Target ▸ **Widget Extension**, name it `TheWayWidget`, uncheck
   "Include Configuration Intent."
2. Replace the generated Swift file with `ios-widget/TheWayWidget.swift`.
3. Add the **same App Group** to the widget target.
4. Optional: drag `www/fonts/cormorant-garamond-latin-300-normal.woff2` into the
   widget target and list it under `UIAppFonts` in the widget's Info.plist. The
   widget falls back to the system font without this — it just looks less like
   The Way.

The widget refreshes at midnight, which covers the case that matters. If you
want it to update the instant you advance a lesson, install
`capacitor-widgetsbridge-plugin`; `native.js` already calls it behind a guard.

---

## Every build after that

```bash
npm run ship     # build + sync + open Xcode
```

Then in Xcode: Product ▸ Archive ▸ Distribute App.

---

## App Store Connect

**Territories — United States only.** Deselect everything else. This is
deliberate: EU distribution requires verified DSA trader status, and Apple then
publishes your legal name, home address, phone and email on the product page in
all 27 EU territories. Revisit once there's an entity to publish instead.

**Age rating questionnaire.** Mandatory since 31 January 2026 — submissions are
blocked without it. The new scale is 4+ / 9+ / 13+ / 16+ / 18+. Two questions
need thought:

- *Medical or wellness topics* — The Way makes no health claims and offers no
  treatment. Answer accordingly, and keep the store description free of any
  language that reads as therapeutic benefit. "Reduces anxiety" is a claim.
  "A daily practice of undoing" is not.
- *In-app controls* — no chat, no user-to-user content, no web browser. All no.

**Privacy nutrition label — "Data Not Collected."** True and easy to defend:
everything lives in `localStorage` on device, there is no account, no analytics,
no network call of any kind. Do not add analytics before launch; it turns a
one-click privacy label into a liability.

**Privacy policy URL** — `https://theunwindingway.com/privacy.html` (already live).
**Support URL** — needs to resolve to something. The About screen's
`curtis@curtisgrubb.org` is fine, but the URL field needs a real page.

**Export compliance** — no encryption beyond standard OS-level HTTPS. Answer
"No" to the proprietary-encryption question.

**Pricing** — free, no in-app purchases.

**Screenshots** — 6.9" and 6.5" iPhone required. Strongest set: the daily
lesson, the six lines mid-cast, a resolved reading, the journal, the About
screen showing the reminder control.

---

## App Review notes

Paste something like this into the review notes field. Reviewers flag webview
apps under 4.2 by default; naming the native functionality up front is the
single cheapest thing you can do.

> The Way is a 365-day contemplative practice. All content ships inside the
> bundle — the app is fully functional with no network connection; please feel
> free to test it in airplane mode.
>
> Native functionality beyond a web experience:
> • Home screen widget (WidgetKit) showing the current day and lesson.
> • Optional daily local notifications, scheduled 60 days ahead so each one
>   carries that day's actual lesson title. Off by default; enable under About.
> • Haptic feedback as each of the six oracle lines resolves, and on completion
>   of a reading.
> • Native share sheet for readings.
>
> No account, no analytics, no data collection. All state is stored on device.

---

## One thing to confirm before you submit

**The lesson text is verbatim ACIM.** A US court voided the Course's copyright
and trademarks in 2004 because early versions circulated without notice, so this
is solid ground — but the ruling covers the first edition (1976–1992), the
Foundation still asserts rights over material added in later editions, and it is
a US ruling only. Worth confirming your lesson text traces to the first edition
before it's in front of a few thousand people. Launching US-only happens to
align with the ruling's reach.
