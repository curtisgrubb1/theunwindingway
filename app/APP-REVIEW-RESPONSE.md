# App Review — response to Guideline 2.1 (Information Needed)

Paste the block below into the **reply** on the App Store Connect review thread,
and also into **App Review Information → Notes** so it's attached to every future
submission and this doesn't get asked again.

Fill in the two bracketed items before sending.

---

## PASTE FROM HERE

**1. Screen recording**

Attached. Recorded on a physical [YOUR IPHONE MODEL] running iOS [VERSION].
It begins at launch and shows the full core flow: the daily lesson, consulting
the oracle, a resolved reading, the journal, the About screen with the optional
reminder, and the home screen widget. It also shows the app running in airplane
mode, since the app is fully functional with no network connection.

The app has no account registration, no login, no account deletion, no paid
content, no purchases, no subscriptions, and no user-generated content that is
shared or published. The only permission prompt is the optional notification
permission, shown in the recording, which appears only if the user turns the
daily reminder on. It is off by default.

**2. Devices and operating systems tested**

- [YOUR IPHONE MODEL], iOS [VERSION] — physical device
- iPhone 17 Pro Max, iOS 26 — Simulator
- iPhone 16, iOS 26 — Simulator

The app is iPhone-only. iPad and Vision Pro are not supported.

**3. Functions and target audience**

The Way is a 365-day contemplative practice app. It presents one lesson per day
from A Course in Miracles, in sequence, and provides an I Ching oracle the user
may consult when a question is unclear. Readings are saved to a private journal
stored on the device.

The audience is adults with an existing interest in contemplative practice —
people already reading A Course in Miracles, consulting the I Ching, or working
with a daily practice of their own.

The problem it addresses is continuity. These traditions ask for daily
attention over a long period, and people lose their place. The app keeps the
sequence, holds the record of what was consulted, and makes the day's material
available in one place without requiring a book, a bookmark, or an internet
connection.

The app makes no health, medical, therapeutic, or wellness claims, and provides
no advice, diagnosis, or treatment of any kind.

**4. Setup and access instructions**

No setup, no login, no credentials, no sample files. The app is fully functional
the moment it is installed.

- **Daily lesson** — shown on launch. "Continue" advances through the reading.
- **Oracle** — from the main screen, choose to consult. Six lines form one at a
  time, and the resolved hexagram and its reading are displayed.
- **Journal** — every reading is saved automatically and can be viewed or
  deleted. It is private to the device and is never transmitted.
- **Daily reminder** — under About. Off by default. Turning it on requests
  notification permission and schedules a local notification at a chosen time.
- **Widget** — a home screen widget showing the current lesson. Add it by
  long-pressing the home screen and searching for "The Way."

To reach any lesson directly, tap the lesson number at the top of the daily
lesson screen and enter a number from 1 to 365.

**5. External services, tools, and platforms**

**None.** The app makes no network requests of any kind.

All content, fonts, and code are contained in the app bundle. There is no
backend, no API, no data provider, no authentication service, no payment
processor, no analytics, no advertising SDK, no crash reporting, and no AI or
machine-learning service. No user data is transmitted anywhere, which is why the
privacy label is Data Not Collected.

The app is built with Capacitor, an open-source native runtime. All state is
stored locally on the device.

**6. Regional differences**

None. The app behaves identically everywhere and contains no region-specific
features, content, or restrictions. It is currently distributed in the United
States only, and English is the only language.

**7. Regulated industry and third-party material**

The app is not in a regulated industry. It makes no medical, health, financial,
or legal claims and provides no regulated services.

Regarding third-party material: the daily lessons are drawn from the workbook of
*A Course in Miracles*, which is in the public domain in the United States. The
copyright and trademarks were held invalid by the U.S. District Court for the
Southern District of New York in *Penguin Books U.S.A., Inc. v. New Christian
Church of Full Endeavor, Ltd.*, No. 96 Civ. 4126 (S.D.N.Y.), on the grounds that
the work had been distributed without copyright notice prior to publication.
Judgment was entered in 2004. The text used in this app is from the first
edition covered by that ruling.

The I Ching is an ancient Chinese text in the public domain worldwide. All
interpretive and commentary text in the app is original work written by the
developer.

## PASTE TO HERE

---

## The screen recording

Roughly 60–90 seconds, on your actual iPhone. Apple specifically asks that it
start with launching the app.

**Set it up:** Settings → Control Centre → add **Screen Recording**. Then swipe
down from the top-right corner and tap the record button.

**What to capture, in order:**

1. Start on the home screen with the widget visible, then tap the icon — this
   shows the widget and the launch in one move
2. The daily lesson, scrolling through the text
3. Tap the lesson number, jump to a different lesson, come back
4. Consult the oracle — let all six lines form
5. The resolved reading, scrolling to the judgment
6. Share a reading, so the share sheet and hexagram card appear
7. The journal, showing saved readings
8. About → turn the daily reminder on → **let the notification permission prompt
   appear and accept it** — Apple explicitly asks to see any permission prompt
9. Turn on airplane mode from Control Centre, force-quit, relaunch, open a
   lesson and cast a reading — proves it works offline

Step 8 matters most. It's the only prompt the app shows, and them seeing it
answers their question about sensitive-data requests directly.

**Getting it off the phone:** AirDrop to your Mac, or Photos → Share → Save to
Files. Trim it in Photos first if it's long.

## Sending it

App Store Connect → your app → **App Review** in the sidebar, where the message
from Apple is. Reply there, paste the block above, and attach the video with the
paperclip.

Then also paste the same block into **App Review Information → Notes** on the
version page. That's what Apple means by "include this information for future
submissions" — it prevents the same request next time.

You do **not** need a new build, and you do **not** need to resubmit. Replying
to the thread returns the app to the review queue on its own.
