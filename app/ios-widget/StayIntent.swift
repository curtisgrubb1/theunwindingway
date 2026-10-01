//
//  StayIntent.swift
//  The Way — "Stay another day" on the widget
//
//  The lesson turns each morning by itself. This is the one way to hold it:
//  tapped, tomorrow keeps today's lesson; tapped again, it turns after all.
//  Runs inside the widget, without opening the app (iOS 17 interactive
//  widgets). The anchor it writes is copied back into the app by
//  TheWayWidgetBridge when the app next comes forward.
//

import AppIntents
import UserNotifications
import WidgetKit

struct StayIntent: AppIntent {
    static let title: LocalizedStringResource = "Stay with this lesson"
    static let description = IntentDescription("Keep today's lesson for tomorrow as well.")
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WayCalendar.toggleStay()
        await ReminderText.update()
        return .result()
    }
}

/// The app schedules the daily reminders ahead of time, each naming the lesson
/// that begins that morning. Staying changes which lesson that is, so rewrite
/// the words of the ones still waiting. Their timing is left exactly as it was.
/// If this cannot run here, nothing is lost: the app reschedules every reminder
/// the next time it opens.
enum ReminderText {
    static func update() async {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        for request in await center.pendingNotificationRequests() {
            guard var extra = request.content.userInfo["cap_extra"] as? [String: Any],
                  let ms = (extra["at"] as? NSNumber)?.doubleValue
            else { continue }
            let fire = Date(timeIntervalSince1970: ms / 1000)
            let interval = fire.timeIntervalSince(now)
            guard interval > 1 else { continue }

            let day = WayCalendar.lesson(on: WayCalendar.practiceDay(fire))
            guard (extra["day"] as? NSNumber)?.intValue != day,
                  let content = request.content.mutableCopy() as? UNMutableNotificationContent
            else { continue }

            extra["day"] = day
            var info = content.userInfo
            info["cap_extra"] = extra
            content.userInfo = info
            content.title = "Lesson \(day)"
            if let plan = Plans.plan(for: day) { content.body = plan.t ?? plan.i }

            let replacement = UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            try? await center.add(replacement)
        }
    }
}
