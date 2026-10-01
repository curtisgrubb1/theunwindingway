//
//  TheWayWidgetBridge.swift
//  The Way — app target
//
//  Copies the current lesson into the shared App Group so the widget can read
//  it, and asks WidgetKit to refresh.
//
//  Two constraints shaped this.
//
//  Capacitor's Preferences plugin cannot reach an App Group: its `group` option
//  is only a key prefix, and it always writes to UserDefaults.standard, which
//  lives in the app's own sandbox. Sharing requires UserDefaults(suiteName:),
//  which is Swift-only.
//
//  And a Capacitor plugin defined in the app target rather than an npm package
//  is not discovered by the bridge — it needs a ViewController subclass and a
//  storyboard change to register. So this is not a plugin. It is a plain helper
//  called from AppDelegate on lifecycle events, which needs no registration and
//  no Xcode wiring at all.
//
//  The JS side writes widget_day and widget_title through Preferences as usual;
//  this reads them back out of standard defaults and mirrors them across. The
//  mirror runs when the app goes inactive or backgrounds — which is precisely
//  when someone leaves to look at their home screen.
//
//  The calendar anchor travels both ways: a Stay tapped on the widget is
//  written into the App Group, and copied back here when the app comes
//  forward, before the web layer asks for it.
//

import Foundation
import WidgetKit

enum TheWayWidgetBridge {

    /// Must match the App Groups entitlement on both the app and the widget.
    private static let group = "group.com.curtisgrubb.theway"

    /// Capacitor namespaces its Preferences keys with this.
    private static let prefix = "CapacitorStorage."

    /// Written by the app only; the widget reads them.
    private static let outbound = ["widget_day", "widget_title", "widget_wake"]

    /// The calendar anchor, which both sides can move: the app when a lesson
    /// is chosen or Stay is tapped there, the widget when Stay is tapped on it.
    /// Whichever was set most recently (widget_anchor_at, in ms) wins.
    private static let anchor = ["widget_anchor_day", "widget_anchor_date", "widget_anchor_at"]

    static func sync() {
        guard let shared = UserDefaults(suiteName: group) else {
            NSLog("[The Way] App Group \(group) unavailable — check the entitlement on both targets")
            return
        }

        let standard = UserDefaults.standard
        func mine(_ key: String) -> String? { standard.string(forKey: prefix + key) ?? standard.string(forKey: key) }

        // A Stay tapped on the widget comes back into the app first, so the
        // copy below cannot overwrite it with the older anchor.
        let appAt = Int64(mine("widget_anchor_at") ?? "") ?? 0
        let widgetAt = Int64(shared.string(forKey: "widget_anchor_at") ?? "") ?? 0
        if widgetAt > appAt {
            for key in anchor {
                if let value = shared.string(forKey: key) { standard.set(value, forKey: prefix + key) }
            }
            NSLog("[The Way] took the widget's anchor — lesson \(shared.string(forKey: "widget_anchor_day") ?? "?")")
        }

        var wrote = false
        for key in outbound + (widgetAt > appAt ? [] : anchor) {
            if let value = mine(key), shared.string(forKey: key) != value {
                shared.set(value, forKey: key)
                wrote = true
            }
        }

        guard wrote else { return }

        // Without this the widget would wait for its next timeline refresh.
        NSLog("[The Way] mirrored to App Group — day \(shared.string(forKey: "widget_day") ?? "?"), anchor \(shared.string(forKey: "widget_anchor_day") ?? "-") on \(shared.string(forKey: "widget_anchor_date") ?? "-")")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
