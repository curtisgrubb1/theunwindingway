# Widget map — each lesson's own practice instructions

The widget follows the lesson through the day: it shows what the lesson asks
for at that hour (morning practice, "on the hour", "every half hour", "as often
as you can", the review ideas in turn, and so on).

Every line the widget shows is taken word for word from the lesson itself, or
from the introduction that governs it (Review I–VI, Part II, Final Lessons).
Nothing is paraphrased.

## Files

- `lessons.json` / `interludes.json` — extracted from `../../../index.html`.
- `map_*.json` — one entry per lesson: when the longer practice periods fall
  (`when`, `n`, `len`), what to do in them (`p`, `pe`), how often between (`f`),
  the short form to repeat (`r`, `r2`), review ideas (`ideas`), and `ev`: the
  lesson's own sentences that establish the schedule.
- `validate.py` — fails if any quoted line is not verbatim in its source.
- `build_widget_json.py` — writes `lessons-widget.json` into the widget and
  Messages targets.
- `simulate.py` — the widget's scheduling logic in Python; prints a day's
  timeline (`python3 simulate.py 1 27 111`).

## Rebuild after changing a map entry

    python3 validate.py && python3 build_widget_json.py

## Where the schedule comes from a governing introduction

- 51–60, 81–90, 111–120, 141–150, 171–180, 201–220: the review introductions.
- Lessons after 153 with no schedule of their own: Lesson 153 ("a form we will
  maintain for quite a while": morning, night, and as the hour strikes).
- 221–365: the Part II introduction (morning and night, hourly remembrance);
  the "What Is…" theme is shown in the morning period, as that introduction asks.
- 361–365: the Final Lessons introduction.

Morning begins at the app's reminder time (7:00 if none is set); the day's
practice ends fifteen hours later, no later than 23:00.
