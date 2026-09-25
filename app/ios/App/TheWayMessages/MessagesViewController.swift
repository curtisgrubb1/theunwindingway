//
//  MessagesViewController.swift
//  TheWayMessages — The Way's iMessage extension
//
//  Two things to offer a friend:
//
//  • A lesson — today's, or any of the 365. Tap the card to choose from the
//    full list; ‹ › step one at a time.
//  • A blessing — lines the Workbook itself addresses to another person
//    ("Light and joy and peace abide in you."), word for word from the lesson
//    each comes from. A lesson that frees you can wound someone else when it
//    is sent to them; these were written to be given.
//
//  Reads the day you are on from the App Group the widget uses
//  (group.com.curtisgrubb.theway, mirrored there by TheWayWidgetBridge), and
//  lesson titles from lessons-widget.json, bundled in this target.
//

import Foundation
import Dispatch
import UIKit
import SwiftUI
import Combine
import Messages

// MARK: - Shared state

private enum Shared {
    static let group = "group.com.curtisgrubb.theway"

    static func string(_ key: String) -> String? {
        guard let defaults = UserDefaults(suiteName: group) else { return nil }
        return defaults.string(forKey: "CapacitorStorage.\(key)")
            ?? defaults.string(forKey: key)
    }

    static var day: Int { min(max(Int(string("widget_day") ?? "") ?? 1, 1), 365) }
}

// MARK: - Content

enum Lessons {
    private struct Idea: Decodable { let i: String }

    /// The idea for each day, 1...365. Review days carry the idea itself,
    /// not "Review of Lessons 51 - 55".
    static let ideas: [String] = {
        guard let url = Bundle.main.url(forResource: "lessons-widget", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Idea].self, from: data)
        else { return [] }
        return list.map(\.i)
    }()

    static var count: Int { max(ideas.count, 1) }

    static func idea(_ day: Int) -> String {
        guard day >= 1, day <= ideas.count else { return "Nothing I see means anything." }
        return ideas[day - 1]
    }
}

struct Blessing: Hashable {
    let lesson: Int
    let text: String
}

/// Words the Workbook addresses to another, verbatim. Where the lesson has
/// ", [name]" the placeholder is left off.
enum Blessings {
    static let all: [Blessing] = [
        Blessing(lesson: 43, text: "God is my Source. I cannot see you apart from Him."),
        Blessing(lesson: 75, text: "The light has come."),
        Blessing(lesson: 82, text: "Let peace extend from my mind to yours."),
        Blessing(lesson: 82, text: "I share the light of the world with you."),
        Blessing(lesson: 87, text: "You stand with me in light."),
        Blessing(lesson: 88, text: "The light in you is all that I would see."),
        Blessing(lesson: 93, text: "Light and joy and peace abide in you."),
        Blessing(lesson: 94, text: "You are as God created you."),
        Blessing(lesson: 95, text: "You are one Self with me, united with our Creator in this Self."),
        Blessing(lesson: 95, text: "I honor you because of What I am, and What He is, Who loves us both as one."),
        Blessing(lesson: 105, text: "My brother, peace and joy I offer you, That I may have God's peace and joy as mine."),
        Blessing(lesson: 127, text: "I bless you, brother, with the Love of God, which I would share with you."),
    ]

    /// The blessing that belongs to a lesson, if the Workbook gives one;
    /// otherwise the first blessing at or after it, wrapping around.
    static func nearest(to day: Int) -> Int {
        all.firstIndex(where: { $0.lesson >= day }) ?? 0
    }
}

enum Kind: String { case lesson, blessing }

/// What travels in the message.
struct Offering: Equatable {
    let kind: Kind
    let day: Int
    let text: String

    var url: URL {
        var c = URLComponents(string: "https://theunwindingway.com/")!
        c.queryItems = [
            URLQueryItem(name: "day", value: String(day)),
            URLQueryItem(name: "title", value: text),
            URLQueryItem(name: "kind", value: kind.rawValue),
        ]
        return c.url!
    }

    init(kind: Kind, day: Int, text: String) {
        self.kind = kind
        self.day = day
        self.text = text
    }

    /// Rebuild what a friend sent. Messages from 1.1 carry no "kind"; they
    /// were lessons.
    init?(url: URL?) {
        guard let url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let d = items.first(where: { $0.name == "day" })?.value.flatMap(Int.init),
              let t = items.first(where: { $0.name == "title" })?.value
        else { return nil }
        self.day = d
        self.text = t
        self.kind = Kind(rawValue: items.first(where: { $0.name == "kind" })?.value ?? "") ?? .lesson
    }
}

// MARK: - State

final class Model: ObservableObject {
    let today = Shared.day
    @Published var kind: Kind = .lesson
    @Published var day: Int = Shared.day
    @Published var blessing: Int = Blessings.nearest(to: Shared.day)
    @Published var expanded = false
    @Published var received: Offering?

    var current: Offering {
        if let received { return received }
        switch kind {
        case .lesson:
            return Offering(kind: .lesson, day: day, text: Lessons.idea(day))
        case .blessing:
            let b = Blessings.all[blessing]
            return Offering(kind: .blessing, day: b.lesson, text: b.text)
        }
    }

    func step(_ delta: Int) {
        switch kind {
        case .lesson:
            day = ((day - 1 + delta) % Lessons.count + Lessons.count) % Lessons.count + 1
        case .blessing:
            let n = Blessings.all.count
            blessing = ((blessing + delta) % n + n) % n
        }
    }
}

// MARK: - Palette

private extension Color {
    static let wayGold = Color(red: 196 / 255, green: 149 / 255, blue: 106 / 255)
    static let wayInk  = Color(red: 14 / 255,  green: 14 / 255,  blue: 12 / 255)
    static let wayText = Color(red: 212 / 255, green: 208 / 255, blue: 200 / 255)
}

private func serif(_ size: CGFloat) -> Font {
    UIFont(name: "CormorantGaramond-Light", size: size) != nil
        ? .custom("CormorantGaramond-Light", size: size)
        : .system(size: size, weight: .light, design: .serif)
}

// MARK: - The card (also what the message bubble becomes)

struct OfferingCard: View {
    let offering: Offering

    private var label: String {
        offering.kind == .blessing ? "A BLESSING" : "LESSON \(offering.day)"
    }
    private var footer: String {
        offering.kind == .blessing ? "LESSON \(offering.day) · THE WAY" : "THE WAY"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .tracking(2.4)
                .foregroundColor(.wayGold.opacity(0.75))

            Rectangle()
                .fill(Color.wayGold.opacity(0.22))
                .frame(width: 28, height: 1)
                .padding(.top, 10)

            Spacer(minLength: 12)

            Text(offering.text)
                .font(serif(offering.kind == .blessing ? 25 : 28))
                .italic(offering.kind == .blessing)
                .foregroundColor(.wayText.opacity(0.92))
                .lineSpacing(4)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Text(footer)
                .font(.system(size: 9))
                .tracking(2.8)
                .foregroundColor(.wayGold.opacity(offering.kind == .blessing ? 0.75 : 0.32))
        }
        .padding(26)
        .frame(width: 300, height: 200, alignment: .leading)
        .background(Color.wayInk)
    }
}

// MARK: - Panels

private struct SmallCaps: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(2.4)
    }
}

private struct KindPicker: View {
    @ObservedObject var model: Model
    var body: some View {
        HStack(spacing: 28) {
            ForEach([Kind.lesson, Kind.blessing], id: \.self) { k in
                Button { model.kind = k } label: {
                    VStack(spacing: 5) {
                        SmallCaps(text: k == .lesson ? "LESSON" : "BLESSING")
                            .foregroundColor(.wayGold.opacity(model.kind == k ? 1.0 : 0.75))
                        Rectangle()
                            .fill(Color.wayGold.opacity(model.kind == k ? 0.6 : 0))
                            .frame(width: 22, height: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ComposeView: View {
    @ObservedObject var model: Model
    let send: () -> Void
    let expand: () -> Void
    let collapse: () -> Void

    var body: some View {
        ZStack {
            Color.wayInk.ignoresSafeArea()
            if model.received != nil {
                receivedPanel
            } else if model.expanded {
                listPanel
            } else {
                compactPanel
            }
        }
    }

    // Someone sent this; show it, nothing to choose.
    private var receivedPanel: some View {
        OfferingCard(offering: model.current)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.wayGold.opacity(0.15), lineWidth: 1))
            .padding()
    }

    private var compactPanel: some View {
        VStack(spacing: 10) {
            KindPicker(model: model)

            HStack(spacing: 4) {
                arrow("‹") { model.step(-1) }
                Button(action: expand) {
                    OfferingCard(offering: model.current)
                        .scaleEffect(0.8)
                        .frame(width: 240, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.wayGold.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                arrow("›") { model.step(1) }
            }

            HStack(spacing: 18) {
                Button(action: send) {
                    SmallCaps(text: model.kind == .lesson ? "OFFER THIS LESSON" : "OFFER THIS BLESSING")
                        .foregroundColor(.wayGold)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 24)
                        .overlay(Capsule().stroke(Color.wayGold.opacity(0.45), lineWidth: 1))
                }
                if model.kind == .lesson && model.day != model.today {
                    Button { model.day = model.today } label: {
                        SmallCaps(text: "TODAY").foregroundColor(.wayGold.opacity(0.75))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func arrow(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.wayGold.opacity(0.75))
                .frame(width: 34, height: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // The full list, when the card is tapped.
    private var listPanel: some View {
        VStack(spacing: 14) {
            KindPicker(model: model).padding(.top, 14)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if model.kind == .lesson {
                            ForEach(1...Lessons.count, id: \.self) { d in
                                row(number: "\(d)", text: Lessons.idea(d),
                                    selected: d == model.day, isToday: d == model.today) {
                                    model.day = d
                                    collapse()
                                }
                                .id("l\(d)")
                            }
                        } else {
                            ForEach(Array(Blessings.all.enumerated()), id: \.offset) { i, b in
                                row(number: "\(b.lesson)", text: b.text,
                                    selected: i == model.blessing, isToday: false) {
                                    model.blessing = i
                                    collapse()
                                }
                                .id("b\(i)")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onAppear { scroll(proxy) }
                .onChange(of: model.kind) { _ in scroll(proxy) }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        let target = model.kind == .lesson ? "l\(model.day)" : "b\(model.blessing)"
        DispatchQueue.main.async { proxy.scrollTo(target, anchor: .center) }
    }

    private func row(number: String, text: String, selected: Bool, isToday: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(number)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(.wayGold.opacity(selected ? 1.0 : 0.75))
                    .frame(width: 30, alignment: .trailing)
                VStack(alignment: .leading, spacing: 3) {
                    Text(text)
                        .font(serif(18))
                        .foregroundColor(.wayText.opacity(selected ? 0.95 : 0.7))
                        .multilineTextAlignment(.leading)
                    if isToday {
                        SmallCaps(text: "TODAY").foregroundColor(.wayGold.opacity(0.75))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Controller

final class MessagesViewController: MSMessagesAppViewController {

    private let model = Model()
    private var host: UIHostingController<ComposeView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 12/255, alpha: 1)

        let root = ComposeView(
            model: model,
            send: { [weak self] in self?.offer() },
            expand: { [weak self] in self?.requestPresentationStyle(.expanded) },
            collapse: { [weak self] in self?.requestPresentationStyle(.compact) }
        )
        let h = UIHostingController(rootView: root)
        h.view.backgroundColor = .clear
        addChild(h)
        h.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(h.view)
        NSLayoutConstraint.activate([
            h.view.topAnchor.constraint(equalTo: view.topAnchor),
            h.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            h.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            h.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        h.didMove(toParent: self)
        host = h
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        model.received = Offering(url: conversation.selectedMessage?.url)
        model.expanded = presentationStyle == .expanded
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        model.received = Offering(url: message.url)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        model.expanded = presentationStyle == .expanded
        // Leaving a friend's message behind returns to choosing your own.
        if presentationStyle == .compact { model.received = nil }
    }

    private func offer() {
        guard let conversation = activeConversation else { return }
        let o = model.current

        let layout = MSMessageTemplateLayout()
        layout.image = render(o)
        layout.caption = o.text
        layout.subcaption = o.kind == .blessing ? "A blessing · Lesson \(o.day) · The Way" : "Lesson \(o.day) · The Way"

        let message = MSMessage(session: MSSession())
        message.layout = layout
        message.url = o.url
        message.summaryText = o.kind == .blessing ? o.text : "Lesson \(o.day): \(o.text)"

        // Places the card in the compose field; the person still taps send.
        conversation.insert(message) { error in
            if let error { print("The Way: insert failed —", error) }
        }
        dismiss()
    }

    @MainActor
    private func render(_ o: Offering) -> UIImage? {
        let renderer = ImageRenderer(content: OfferingCard(offering: o))
        renderer.scale = 3
        return renderer.uiImage
    }
}
