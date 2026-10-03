import AppKit

/// The twelve collectible tomatoes. The raw value is the sticker's file name.
enum TomatoKind: String, CaseIterable, Codable, Identifiable {
    case confused, sleepy, zen, happy, love, laptop, cool, ninja, levelup, king, angry, exhausted

    var id: String { rawValue }

    var name: String {
        switch self {
        case .confused: return "Verwirrt"
        case .sleepy: return "Schläfrig"
        case .zen: return "Zen"
        case .happy: return "Fröhlich"
        case .love: return "Verliebt"
        case .laptop: return "Fokus"
        case .cool: return "Cool"
        case .ninja: return "Ninja"
        case .levelup: return "Aufsteiger"
        case .king: return "König"
        case .angry: return "Wütend"
        case .exhausted: return "Erschöpft"
        }
    }

    /// How to earn it — shown as tooltip in the collection.
    var hint: String {
        switch self {
        case .confused: return "Eine Session unter 5 min beenden"
        case .sleepy: return "5–9 min fokussieren"
        case .zen: return "10–14 min fokussieren"
        case .happy: return "15–19 min fokussieren"
        case .love: return "20–24 min fokussieren"
        case .laptop: return "25–29 min fokussieren"
        case .cool: return "30–39 min fokussieren"
        case .ninja: return "40–49 min fokussieren"
        case .levelup: return "50–59 min fokussieren"
        case .king: return "Volle 60 min fokussieren"
        case .angry: return "Eine Session nach mindestens 5 min abbrechen"
        case .exhausted: return "An einem Tag 4 Stunden Fokus erreichen"
        }
    }

    @MainActor var image: NSImage { TomatoArt.image(rawValue) }
}

enum TomatoRules {
    static let exhaustedAfter: TimeInterval = 4 * 3600
    static let angryAfter: TimeInterval = 5 * 60

    /// The tomato a completed session earns, by its planned length.
    static func forCompleted(minutes: Int) -> TomatoKind {
        switch minutes {
        case ..<5: return .confused
        case 5..<10: return .sleepy
        case 10..<15: return .zen
        case 15..<20: return .happy
        case 20..<25: return .love
        case 25..<30: return .laptop
        case 30..<40: return .cool
        case 40..<50: return .ninja
        case 50..<60: return .levelup
        default: return .king
        }
    }

    /// Everything one session earns. `focusTodayBefore` is the focus time already
    /// logged today, so the exhausted tomato comes once — on the session that crosses 4 h.
    static func awards(
        completed: Bool,
        plannedMinutes: Int,
        focusedSeconds: TimeInterval,
        focusTodayBefore: TimeInterval
    ) -> [TomatoKind] {
        guard completed else {
            return focusedSeconds >= angryAfter ? [.angry] : []
        }
        var result = [forCompleted(minutes: plannedMinutes)]
        if focusTodayBefore < exhaustedAfter && focusTodayBefore + focusedSeconds >= exhaustedAfter {
            result.append(.exhausted)
        }
        return result
    }
}
