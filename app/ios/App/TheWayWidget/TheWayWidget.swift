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
import SwiftUI

// MARK: - Shared state (mirrored by TheWayWidgetBridge in the app)

private enum Shared {
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
            return m < 5 ? Moment(label: "AS THE HOUR STRIKES", text: plan.r ?? idea, note: nil) : plain
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
    static let wayText = Color(red: 212 / 255, green: 208 / 255, blue: 200 / 255)
}

// MARK: - Timeline

struct LessonEntry: TimelineEntry {
    let date: Date
    let day: Int
    let moment: Moment

    static let placeholder = LessonEntry(
        date: Date(),
        day: 1,
        moment: Moment(label: "LESSON 1", text: "Nothing I see means anything.", note: nil)
    )
}

struct LessonProvider: TimelineProvider {
    func placeholder(in context: Context) -> LessonEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (LessonEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LessonEntry>) -> Void) {
        // Walk the rest of today in five-minute steps and keep only the
        // moments where what the lesson asks for changes.
        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)
        let midnight = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? now.addingTimeInterval(3600)

        var entries: [LessonEntry] = [entry(at: now)]
        let nowMinute = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        var minute = (nowMinute / 5 + 1) * 5
        while minute < 24 * 60 {
            let date = startOfDay.addingTimeInterval(TimeInterval(minute * 60))
            let next = entry(at: date)
            if next.moment != entries.last?.moment { entries.append(next) }
            minute += 5
        }

        // After midnight the app sets the new day when it next opens; until
        // then the widget stays on the lesson it knows.
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func entry(at date: Date) -> LessonEntry {
        let cal = Calendar.current
        let minute = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        let day = Shared.day
        return LessonEntry(
            date: date,
            day: day,
            moment: Practice.moment(day: day, fallbackTitle: Shared.title, at: minute, wake: Shared.wakeMinutes)
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

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.moment.text)
                .containerBackground(for: .widget) { Color.clear }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.moment.label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                    .opacity(0.7)
                Text(entry.moment.text)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
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
                        .opacity(0.7)
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
            Text(entry.moment.label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.8)
                .foregroundColor(.wayGold.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Rectangle()
                .fill(Color.wayGold.opacity(0.18))
                .frame(width: 26, height: 1)
                .padding(.top, 7)

            Spacer(minLength: 6)

            Text(entry.moment.text)
                .font(serif(small ? 16 : 19))
                .foregroundColor(.wayText.opacity(0.9))
                .lineSpacing(2)
                .lineLimit(small ? 5 : 4)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline) {
                Text("LESSON \(entry.day)")
                    .font(.system(size: 8))
                    .tracking(2.4)
                    .foregroundColor(.wayGold.opacity(0.75))
                if !small, let note = entry.moment.note {
                    Spacer()
                    Text(note)
                        .font(serif(12).italic())
                        .foregroundColor(.wayGold.opacity(0.75))
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
