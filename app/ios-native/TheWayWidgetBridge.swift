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

import Foundation
import WidgetKit

enum TheWayWidgetBridge {

    /// Must match the App Groups entitlement on both the app and the widget.
    private static let group = "group.com.curtisgrubb.theway"

    /// Capacitor namespaces its Preferences keys with this.
    private static let prefix = "CapacitorStorage."

    static func sync() {
        guard let shared = UserDefaults(suiteName: group) else {
            NSLog("[The Way] App Group \(group) unavailable — check the entitlement on both targets")
            return
        }

        let standard = UserDefaults.standard
        var wrote = false

        for key in ["widget_day", "widget_title"] {
            if let value = standard.string(forKey: prefix + key) ?? standard.string(forKey: key) {
                shared.set(value, forKey: key)
                wrote = true
            }
        }

        guard wrote else {
            let candidates = standard.dictionaryRepresentation().keys
                .filter { $0.contains("widget_") }
                .sorted()
            NSLog("[The Way] nothing to mirror. Keys containing widget_: \(candidates)")
            return
        }

        // Without this the widget waits for its next timeline date, which is
        // midnight — so advancing a lesson would appear to do nothing all day.
        NSLog("[The Way] mirrored to App Group — day \(shared.string(forKey: "widget_day") ?? "?"), title \(shared.string(forKey: "widget_title") ?? "?")")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
