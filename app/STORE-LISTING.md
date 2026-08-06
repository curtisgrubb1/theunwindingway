# App Store listing

Paste-ready. Character limits are Apple's; counts are current.

---

## Names

**App Name** (30 max) — *App Store Connect ▸ App Information*

```
The Unwinding Way
```
17 characters. Distinctive, matches the domain, and clears the crowded field of
apps already named "The Way."

**Display Name** (what appears under the icon)

```
The Way
```
Set by `appName` in `capacitor.config.json` — already correct. A shortened
display name is standard practice and Apple expects it; anything past about
12 characters truncates on the home screen anyway.

**Subtitle** (30 max)

```
A daily practice of undoing
```
27 characters. The app's own line, not a pitch.

---

## Categories

**Primary: Lifestyle**
**Secondary: Reference**

Deliberately **not** Health & Fitness. That category invites scrutiny of
therapeutic claims and pulls the age-rating questionnaire toward the medical and
wellness questions. The app makes no health claims; the category should say so too.

---

## Promotional text (170 max — editable anytime without a new build)

```
One lesson each day, for a year. An oracle for when the way is unclear. A practice of letting go. No account, no tracking, nothing to buy.
```
136 characters.

---

## Description (4000 max)

```
The Way is a daily practice. One lesson each day, for a year.

Three traditions, working together.

A Course in Miracles gives the structure — 365 lessons, in order, one per day. You don't skip ahead. The sequence is the practice.

The I Ching gives the seeing. When the way is unclear, you consult the oracle. Six lines form. What they say is read through the lesson you are on, not apart from it.

Releasing gives the method. Not analysis. Not affirmation. Only the letting go of what is in the way.

Nothing to acquire. Nothing to become. Only what is in the way to be released.


WHAT IS IN IT

365 daily lessons, in sequence.
All 64 hexagrams, with moving lines and resolving readings.
A journal that saves every reading as it happens.
The full hexagram library, open at any time.
An optional daily reminder — off unless you ask for it.
A home screen widget showing the day you are on.


HOW IT WORKS

No account. No sign-in. No analytics. Nothing is collected and nothing is sent anywhere — everything stays on your device. The app works with no network connection at all.

Free. No subscription, no in-app purchases, no advertising.
```

Written to stay clear of therapeutic claims. "Reduces anxiety" is a claim.
"A daily practice of undoing" is a description. Keep any future edits on the
right side of that line — the description is what a reviewer reads against your
age-rating answers.

---

## Keywords (100 max, comma-separated, no spaces after commas)

```
i ching,hexagram,oracle,contemplation,practice,acim,course in miracles,releasing,stillness
```
90 characters.

Do not repeat words already in the name or subtitle — Apple indexes those
separately and repeating them wastes the budget.

On `course in miracles`: the trademark was voided by a US court in 2004 alongside
the copyright, so this is usable. If Apple's metadata review ever flags it as a
third-party mark, that ruling is the reply.

---

## URLs

| Field | Value |
|---|---|
| Support URL | needs a real page — see below |
| Marketing URL | `https://theunwindingway.com` |
| Privacy Policy URL | `https://theunwindingway.com/privacy.html` |

**Support URL is a required field and must resolve.** The About screen's mailto
link is not enough. Cheapest fix: a `support.html` on the site with a sentence
and your email. Say the word and I'll write it.

---

## Pricing and availability

- **Price:** Free
- **In-app purchases:** None
- **Territories:** United States only — deselect everything else

US-only is the deliberate choice from earlier: EU distribution requires verified
DSA trader status, which publishes your legal name, home address, phone and email
on the product page across all 27 EU territories. It also keeps distribution
inside the reach of the 2004 ruling on the Course's copyright.

---

## Age rating questionnaire

Mandatory since 31 January 2026 — submissions are blocked without it.

| Question | Answer |
|---|---|
| Medical or wellness topics | None — no health claims, no treatment, no diagnosis |
| Violent themes | None |
| Sexual content, nudity, profanity | None |
| Horror or fear themes | None |
| Gambling, contests | None |
| Alcohol, tobacco, drugs | None |
| User-generated content / chat | None — the journal is private and on-device |
| In-app web browser | None |
| Unrestricted internet access | None — the app makes no network calls |

Expected outcome: **4+**.

---

## Privacy nutrition label

**Data Not Collected.** Every category, no exceptions.

True and easy to defend: no account, no analytics, no network calls of any kind,
all state in `localStorage` on device. Do not add analytics before launch — it
converts a one-click privacy label into an ongoing disclosure obligation.

---

## Screenshots

Required: **6.9-inch** and **6.5-inch** iPhone. Up to 10 each; 3–5 is plenty.

Suggested order — the first two are all most people see:

1. The daily lesson
2. The six lines mid-cast
3. A resolved reading with moving lines
4. The journal
5. About, showing the daily reminder control

Take them in the simulator: `⌘S` saves a correctly-sized screenshot to Desktop.
No text overlays or device frames needed — the app's own typography is the pitch.
