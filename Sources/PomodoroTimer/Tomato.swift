import AppKit

/// The eight collectible tomatoes, in ascending value. The raw value is the sticker's file name.
enum TomatoKind: String, CaseIterable, Codable, Identifiable {
    case zen, happy, love, laptop, cool, ninja, levelup, king

    var id: String { rawValue }

    /// Minimum length of a completed session that earns this tomato.
    var minutes: Int {
        switch self {
        case .zen: return 5
        case .happy: return 10
        case .love: return 15
        case .laptop: return 25
        case .cool: return 30
        case .ninja: return 40
        case .levelup: return 50
        case .king: return 60
        }
    }

    var points: Int {
        switch self {
        case .zen: return 5
        case .happy: return 10
        case .love: return 20
        case .laptop: return 35
        case .cool: return 50
        case .ninja: return 75
        case .levelup: return 100
        case .king: return 150
        }
    }

    var name: String {
        switch self {
        case .zen: return "Zen"
        case .happy: return "Fröhlich"
        case .love: return "Verliebt"
        case .laptop: return "Fokus"
        case .cool: return "Cool"
        case .ninja: return "Ninja"
        case .levelup: return "Aufsteiger"
        case .king: return "König"
        }
    }

    @MainActor var image: NSImage { TomatoArt.image(rawValue) }
}

enum TomatoRules {
    /// Bonus for planned tasks confirmed as done after a session — capped,
    /// so splitting work into many tiny tasks earns nothing extra.
    static let pointsPerTask = 10
    static let maxBonusTasks = 3

    /// The most valuable tomato a completed session of this length earns; none below 5 min.
    static func tomato(forMinutes minutes: Int) -> TomatoKind? {
        TomatoKind.allCases.last { minutes >= $0.minutes }
    }

    static func bonus(tasksDone: Int) -> Int {
        min(max(tasksDone, 0), maxBonusTasks) * pointsPerTask
    }
}
