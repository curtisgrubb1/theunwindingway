//
//  TheWayWidget.swift
//  The Way — home screen and lock screen widget
//
//  Follows the lesson through the day. Each Workbook lesson says when and how
//  it is to be practiced — morning and evening, three or four times, on the
//  hour, every half hour, as often as you can. lessons-widget.json holds that
//  schedule for all 365 lessons, taken from the lesson's own words (or the
//  review / Part II introduction that governs it). The widget shows, at any
//  moment, what the lesson asks of that moment.
//
//  The schedule is built by app/tools/widget-map/build_widget_json.py.
//  Do not edit lessons-widget.json by hand.
//

import WidgetKit
import AppIntents
import SwiftUI

// MARK: - Shared state (mirrored by TheWayWidgetBridge in the app)

enum Shared {
    static let group = "group.com.curtisgrubb.theway"

    static func string(_ key: String) -> String? {
        guard let defaults = UserDefaults(suiteName: group) else { return nil }
        return defaults.string(forKey: "CapacitorStorage.\(key)")
            ?? defaults.string(forKey: key)
    }

    static var day: Int { min(max(Int(string("widget_day") ?? "") ?? 1, 1), 365) }
    static var title: String { string("widget_title") ?? "Begin." }

    /// Minutes after midnight the day's practice begins. Taken from the app's
    /// reminder time ("HH:MM"); 7:00 if none has been set.
    static var wakeMinutes: Int {
        let parts = (string("widget_wake") ?? "07:00").split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return 7 * 60 }
        return parts[0] * 60 + parts[1]
    }

    /// The calendar anchor: lesson `L` was the lesson on practice date `D`.
    /// Written by the app, or by StayIntent when Stay is tapped here.
    static var anchor: (L: Int, D: Int)? {
        guard let L = Int(string("widget_anchor_day") ?? ""), (1...365).contains(L),
              let D = WayCalendar.parse(string("widget_anchor_date") ?? "")
        else { return nil }
        return (L, D)
    }

    static func setAnchor(_ L: Int, _ D: Int) {
        guard let defaults = UserDefaults(suiteName: group) else { return }
        // Later than any stamp already seen, so this Stay wins even if the
        // phone's clock was set ahead when the last anchor was written.
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let prev = Int64(defaults.string(forKey: "widget_anchor_at") ?? "") ?? 0
        let values = [
            "widget_anchor_day": String(L),
            "widget_anchor_date": WayCalendar.key(D),
            "widget_anchor_at": String(max(now, prev + 1)),
            "widget_day": String(L),
        ]
        for (k, v) in values {
            defaults.set(v, forKey: k)
            defaults.removeObject(forKey: "CapacitorStorage.\(k)")
        }
    }
}

// MARK: - The calendar
//
// The lesson turns each morning by itself, as the Workbook gives one lesson a
// day. Today's lesson is the anchor's lesson plus the days since its date. The
// day turns at the wake time (the app's reminder time), not at midnight, so
// the evening's lesson is still the one shown at night. index.html and
// native.js do the same arithmetic on the same values.

enum WayCalendar {
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// The practice date of a moment, as whole days since 1970.
    static func practiceDay(_ date: Date, wake: Int = Shared.wakeMinutes) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        guard let midnight = utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) else { return 0 }
        let days = Int((midnight.timeIntervalSince1970 / 86400).rounded())
        return minute < wake ? days - 1 : days
    }

    static func parse(_ s: String) -> Int? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, let d = utc.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return nil }
        return Int((d.timeIntervalSince1970 / 86400).rounded())
    }

    static func key(_ n: Int) -> String {
        let d = utc.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: TimeInterval(n) * 86400))
        return String(format: "%04d-%02d-%02d", d.year ?? 1970, d.month ?? 1, d.day ?? 1)
    }

    /// The lesson on a practice date. Without an anchor (the app has not run
    /// since this update) it is simply the lesson the app last wrote.
    static func lesson(on day: Int) -> Int {
        guard let a = Shared.anchor else { return Shared.day }
        return min(365, a.L + max(0, day - a.D))
    }

    /// Whether tomorrow keeps the lesson of the given practice date.
    static func staying(on day: Int) -> Bool {
        guard let a = Shared.anchor else { return false }
        return a.D > day
    }

    /// Stay with today's lesson tomorrow, or — tapped again — move on after all.
    static func toggleStay(now: Date = Date()) {
        let today = practiceDay(now)
        let L = lesson(on: today)
        Shared.setAnchor(L, staying(on: today) ? today : today + 1)
    }
}

// MARK: - The lesson's own schedule

struct DayPlan: Decodable {
    let i: String          // the idea for the day
    let w: String          // when the longer practice periods fall
    let n: Int             // how many longer practice periods
    let len: String?       // how long, in the lesson's words
    let p: String?         // what to do in the practice period
    let pe: String?        // evening practice, when it differs
    let f: String          // how often between practice periods
    let r: String?         // the short form to repeat
    let r2: String?        // the half-hour thought (Review III)
    let b: String?         // before sleep
    let th: String?        // Part II special theme
    let tt: String?        // its title ("What Is Forgiveness?")
    let ideas: [String]?   // review ideas
    let t: String?         // the lesson's title, when it differs from the idea
}

enum Plans {
    static let all: [DayPlan] = {
        guard let url = Bundle.main.url(forResource: "lessons-widget", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let plans = try? JSONDecoder().decode([DayPlan].self, from: data)
        else { return [] }
        return plans
    }()

    static func plan(for day: Int) -> DayPlan? {
        guard day >= 1, day <= all.count else { return nil }
        return all[day - 1]
    }
}

/// What the widget shows at one moment.
struct Moment: Equatable {
    let label: String      // small caps line above
    let text: String       // the words
    let note: String?      // e.g. "a minute or so"
}

enum Practice {

    /// The moment a lesson asks for at a given minute of the day.
    static func moment(day: Int, fallbackTitle: String, at minute: Int, wake: Int) -> Moment {
        guard let plan = Plans.plan(for: day) else {
            return Moment(label: "LESSON \(day)", text: fallbackTitle, note: nil)
        }

        let sleep = min(wake + 15 * 60, 23 * 60)
        let hour = minute / 60
        let m = minute % 60
        let idea = plan.i
        let plain = Moment(label: "LESSON \(day)", text: idea, note: nil)

        // Night: before the day's practice begins, and after it ends.
        if minute < wake { return plain }
        if minute >= sleep {
            if let b = plan.b { return Moment(label: "BEFORE SLEEP", text: b, note: nil) }
            return plain
        }

        // Longer practice periods.
        if let practice = practiceMoment(plan, minute: minute, wake: wake, sleep: sleep, idea: idea) {
            return practice
        }

        // Between them.
        switch plan.f {
        case "hourly":
            // Part II calls it "our hourly remembrance"; earlier lessons, "as the hour strikes".
            let hourLabel = day >= 221 ? "HOURLY REMEMBRANCE" : "AS THE HOUR STRIKES"
            return m < 5 ? Moment(label: hourLabel, text: plan.r ?? idea, note: nil) : plain
        case "halfhour":
            return (m < 5 || (30..<35).contains(m))
                ? Moment(label: "EVERY HALF HOUR", text: plan.r ?? idea, note: nil) : plain
        case "hourhalf":
            return m < 30
                ? Moment(label: "ON THE HOUR", text: plan.r ?? idea, note: nil)
                : Moment(label: "ON THE HALF HOUR", text: plan.r2 ?? idea, note: nil)
        case "quarter":
            return Moment(label: "EVERY QUARTER HOUR", text: plan.r ?? idea, note: nil)
        case "twenty":
            return Moment(label: "THREE TIMES AN HOUR", text: plan.r ?? idea, note: nil)
        case "ten":
            return Moment(label: "EVERY TEN MINUTES", text: plan.r ?? idea, note: nil)
        case "often":
            let text = (hour % 2 == 1) ? (plan.r ?? idea) : idea
            return Moment(label: "AS OFTEN AS YOU CAN", text: text, note: nil)
        case "asneeded":
            let text = (hour % 2 == 1) ? (plan.r ?? idea) : idea
            return Moment(label: "WHENEVER IT IS NEEDED", text: text, note: nil)
        case "cycle":
            if let ideas = plan.ideas, !ideas.isEmpty {
                let k = hour % ideas.count
                return Moment(label: "REVIEW · \(k + 1) OF \(ideas.count)", text: ideas[k], note: nil)
            }
            return plain
        case "cyclehour":
            if let ideas = plan.ideas, ideas.count >= 3 {
                if m < 5 { return Moment(label: "AS THE HOUR STRIKES", text: ideas[0], note: nil) }
                return Moment(label: "REVIEW", text: ideas[1 + hour % 2], note: nil)
            }
            return plain
        case "split":
            if let ideas = plan.ideas, ideas.count >= 2 {
                let mid = (wake + sleep) / 2
                return minute < mid
                    ? Moment(label: "EARLIER PART OF THE DAY", text: ideas[0], note: nil)
                    : Moment(label: "LATTER PART OF THE DAY", text: ideas[1], note: nil)
            }
            return plain
        default:
            return plain
        }
    }

    private static func practiceMoment(_ plan: DayPlan, minute: Int, wake: Int, sleep: Int, idea: String) -> Moment? {
        let morning = wake..<(wake + 90)
        let evening = (sleep - 90)..<sleep
        // The lesson leads in the morning. (Part II's "What Is…" themes are too
        // long for a widget and displaced the lesson; they stay in the app.)
        let morningText = plan.p ?? idea
        let eveningText = plan.pe ?? plan.p ?? idea
        let morningLabel = "MORNING PRACTICE"

        switch plan.w {
        case "ampm":
            if morning.contains(minute) { return Moment(label: morningLabel, text: morningText, note: plan.len) }
            if evening.contains(minute) { return Moment(label: "EVENING PRACTICE", text: eveningText, note: plan.len) }
        case "wakesleep":
            if morning.contains(minute) { return Moment(label: "AS YOU WAKE", text: morningText, note: plan.len) }
            if evening.contains(minute) { return Moment(label: "BEFORE SLEEP", text: plan.b ?? eveningText, note: plan.len) }
        case "wake":
            if morning.contains(minute) { return Moment(label: "AS YOU WAKE", text: morningText, note: plan.len) }
        case "ampm1":
            let mid = (wake + sleep) / 2
            if morning.contains(minute) { return Moment(label: "MORNING PRACTICE", text: morningText, note: plan.len) }
            if (mid..<(mid + 45)).contains(minute) { return Moment(label: "PRACTICE · IN BETWEEN", text: morningText, note: plan.len) }
            if evening.contains(minute) { return Moment(label: "EVENING PRACTICE", text: eveningText, note: plan.len) }
        case "self":
            let label = plan.n <= 1 ? "ONCE TODAY · A TIME YOU CHOOSE" : "AT A TIME YOU CHOOSE"
            if morning.contains(minute) { return Moment(label: label, text: morningText, note: plan.len) }
            if plan.n >= 2, evening.contains(minute) { return Moment(label: label, text: eveningText, note: plan.len) }
        case "split":
            let mid = (wake + sleep) / 2
            let ideas = plan.ideas ?? []
            if morning.contains(minute) {
                return Moment(label: "EARLIER PART OF THE DAY", text: ideas.first ?? idea, note: plan.len)
            }
            if (mid..<(mid + 45)).contains(minute) {
                return Moment(label: "LATTER PART OF THE DAY", text: ideas.count > 1 ? ideas[1] : idea, note: plan.len)
            }
        case "hourly5":
            if minute % 60 < 5 {
                return Moment(label: "FIRST FIVE MINUTES OF THE HOUR", text: plan.p ?? idea, note: nil)
            }
        case "spread":
            let n = max(plan.n, 1)
            let first = wake + 60
            let last = sleep - 60
            for k in 0..<n {
                let start = n == 1 ? first : first + k * (last - first) / (n - 1)
                if (start..<(start + 30)).contains(minute) {
                    return Moment(label: "PRACTICE · \(k + 1) OF \(n)", text: plan.p ?? idea, note: plan.len)
                }
            }
        default:
            break
        }
        return nil
    }
}

// MARK: - Palette

private extension Color {
    static let wayGold = Color(red: 196 / 255, green: 149 / 255, blue: 106 / 255)
    static let wayInk = Color(red: 14 / 255, green: 14 / 255, blue: 12 / 255)
    // Brighter than the app's body text: a widget is read at a glance, often
    // small and against a bright room.
    static let wayText = Color(red: 240 / 255, green: 235 / 255, blue: 226 / 255)
}

// MARK: - Timeline

struct LessonEntry: TimelineEntry {
    let date: Date
    let day: Int
    let moment: Moment
    var staying: Bool = false

    static let placeholder = LessonEntry(
        date: Date(),
        day: 1,
        moment: Moment(label: "LESSON 1", text: "Nothing I see means anything.", note: nil)
    )

    func sameAs(_ other: LessonEntry?) -> Bool {
        guard let other else { return false }
        return day == other.day && moment == other.moment && staying == other.staying
    }
}

struct LessonProvider: TimelineProvider {
    func placeholder(in context: Context) -> LessonEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (LessonEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LessonEntry>) -> Void) {
        // Walk the next twenty-four hours in five-minute steps and keep only
        // the moments where what the widget shows changes. The span always
        // crosses the next wake time, so the new lesson arrives on its own
        // each morning, whether or not the app has been opened.
        let now = Date()
        let step: TimeInterval = 5 * 60
        let start = (now.timeIntervalSinceReferenceDate / step).rounded(.down) * step + step
        let end = now.addingTimeInterval(24 * 3600)

        var entries: [LessonEntry] = [entry(at: now)]
        var date = Date(timeIntervalSinceReferenceDate: start)
        while date < end {
            let next = entry(at: date)
            if !next.sameAs(entries.last) { entries.append(next) }
            date = date.addingTimeInterval(step)
        }
        completion(Timeline(entries: entries, policy: .after(end)))
    }

    private func entry(at date: Date) -> LessonEntry {
        let cal = Calendar.current
        let minute = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        let wake = Shared.wakeMinutes
        let today = WayCalendar.practiceDay(date, wake: wake)
        let day = WayCalendar.lesson(on: today)
        return LessonEntry(
            date: date,
            day: day,
            moment: Practice.moment(day: day, fallbackTitle: Shared.title, at: minute, wake: wake),
            staying: WayCalendar.staying(on: today)
        )
    }
}

// MARK: - View

private func serif(_ size: CGFloat) -> Font {
    UIFont(name: "CormorantGaramond-Light", size: size) != nil
        ? .custom("CormorantGaramond-Light", size: size)
        : .system(size: size, weight: .light, design: .serif)
}

struct TheWayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LessonEntry

    private var isLong: Bool { entry.moment.text.count > 80 }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.moment.text)
                .containerBackground(for: .widget) { Color.clear }

        case .accessoryRectangular:
            // A long idea (Lessons 347–360) needs the whole space:
            // the label steps aside so the last line, where the idea arrives,
            // is never cut.
            VStack(alignment: .leading, spacing: 2) {
                if !isLong {
                    Text(entry.moment.label)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .widgetAccentable()
                        .opacity(0.85)
                }
                Text(entry.moment.text)
                    .font(.system(size: isLong ? 12 : 13, weight: .regular, design: .serif))
                    .lineLimit(isLong ? 4 : 3)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("LESSON")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(1)
                        .opacity(0.85)
                    Text("\(entry.day)")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                }
            }
            .containerBackground(for: .widget) { Color.clear }

        default:
            homeScreen
        }
    }

    private var homeScreen: some View {
        let small = family == .systemSmall
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.moment.label)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.8)
                    .foregroundColor(.wayGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !small && entry.day < 365 {
                    Spacer(minLength: 8)
                    // Staying is always a choice. Tapped again, it lets the
                    // lesson turn tomorrow after all.
                    Button(intent: StayIntent()) {
                        Text(entry.staying ? "STAYING ANOTHER DAY" : "STAY ANOTHER DAY")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(1.6)
                            .foregroundColor(.wayGold.opacity(entry.staying ? 1 : 0.8))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(Color.wayGold.opacity(0.35))
                .frame(width: 26, height: 1)
                .padding(.top, 7)

            Spacer(minLength: 6)

            Text(entry.moment.text)
                .font(serif(small ? 16 : 19))
                .foregroundColor(.wayText)
                .lineSpacing(2)
                .lineLimit(small ? 5 : 4)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline) {
                Text("LESSON \(entry.day)")
                    .font(.system(size: 8))
                    .tracking(2.4)
                    .foregroundColor(.wayGold)
                if !small, let note = entry.moment.note {
                    Spacer()
                    Text(note)
                        .font(serif(12).italic())
                        .foregroundColor(.wayGold)
                        .lineLimit(1)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.wayInk }
    }
}

// MARK: - Widget

@main
struct TheWayWidget: Widget {
    let kind = "TheWayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LessonProvider()) { entry in
            TheWayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Lesson")
        .description("The lesson you are on, as it asks to be practiced at this hour.")
        .supportedFamilies([
            .systemSmall, .systemMedium,                                   // Home Screen
            .accessoryInline, .accessoryRectangular, .accessoryCircular,   // Lock Screen
        ])
    }
}
