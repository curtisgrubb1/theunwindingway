//
//  TheWayWidget.swift
//  The Way — home screen widget
//
//  Shows the day you are on and the lesson that belongs to it.
//
//  Reads state the web layer mirrors into the shared App Group via the
//  Capacitor Preferences plugin. Nothing is computed here; the widget is a
//  window onto the practice, not a second source of truth.
//
//  Add to Xcode:  File ▸ New ▸ Target ▸ Widget Extension  (name: TheWayWidget,
//  uncheck "Include Configuration Intent"), then replace the generated file
//  with this one and add the App Group to BOTH targets.
//

import WidgetKit
import SwiftUI

// MARK: - Shared state

private enum Shared {
    static let group = "group.com.curtisgrubb.theway"

    /// Capacitor Preferences namespaces its keys. Fall back to the bare key so
    /// this keeps working if that prefix ever changes.
    static func string(_ key: String) -> String? {
        guard let defaults = UserDefaults(suiteName: group) else { return nil }
        return defaults.string(forKey: "CapacitorStorage.\(key)")
            ?? defaults.string(forKey: key)
    }

    static var day: Int { Int(string("widget_day") ?? "") ?? 1 }
    static var title: String { string("widget_title") ?? "Begin." }
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
    let title: String

    static let placeholder = LessonEntry(
        date: Date(),
        day: 1,
        title: "Nothing I See Means Anything."
    )
}

struct LessonProvider: TimelineProvider {
    func placeholder(in context: Context) -> LessonEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (LessonEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LessonEntry>) -> Void) {
        // One entry, refreshed at midnight. The lesson does not change during
        // the day, and the app reloads timelines itself whenever the day turns.
        let midnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)

        completion(Timeline(entries: [current()], policy: .after(midnight)))
    }

    private func current() -> LessonEntry {
        LessonEntry(date: Date(), day: Shared.day, title: Shared.title)
    }
}

// MARK: - View

struct TheWayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LessonEntry

    private var titleLimit: Int { family == .systemSmall ? 3 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DAY \(entry.day)")
                .font(.system(size: 10, weight: .medium, design: .default))
                .tracking(2.2)
                .foregroundColor(.wayGold.opacity(0.55))

            Rectangle()
                .fill(Color.wayGold.opacity(0.18))
                .frame(width: 26, height: 1)
                .padding(.top, 8)

            Spacer(minLength: 8)

            Text(entry.title)
                .font(.custom("CormorantGaramond-Light", size: family == .systemSmall ? 17 : 21))
                .foregroundColor(.wayText.opacity(0.88))
                .lineSpacing(3)
                .lineLimit(titleLimit)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("THE WAY")
                .font(.system(size: 8, weight: .regular))
                .tracking(2.6)
                .foregroundColor(.wayGold.opacity(0.28))
                .padding(.top, 10)
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
        .description("The day you are on, and the lesson that belongs to it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
