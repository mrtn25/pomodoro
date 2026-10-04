import AppKit
import Foundation

// MARK: - Sessions

struct FocusSession: Codable, Identifiable {
    var id = UUID()
    let startedAt: Date
    let endedAt: Date
    let plannedMinutes: Int
    let focusedSeconds: TimeInterval
    let completed: Bool
    /// How often another app came to the front while the timer ran.
    let appSwitches: Int
    let tomato: TomatoKind?
    /// Titles of the tasks that were open when the session started.
    let tasks: [String]
    /// How many of them were confirmed done afterwards; nil until reviewed.
    var tasksDone: Int?

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, plannedMinutes, focusedSeconds, completed, appSwitches, tomato, tasks, tasksDone
    }

    var bonusPoints: Int { TomatoRules.bonus(tasksDone: tasksDone ?? 0) }
    var points: Int { (tomato?.points ?? 0) + bonusPoints }
    var needsReview: Bool { completed && !tasks.isEmpty && tasksDone == nil }
}

extension FocusSession {
    /// Fields written by the first version of the app.
    private enum LegacyKeys: String, CodingKey { case tomatoes, task }

    /// Reads current and first-version sessions; a tomato that no longer exists becomes nil.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decode(Date.self, forKey: .endedAt)
        plannedMinutes = try c.decode(Int.self, forKey: .plannedMinutes)
        focusedSeconds = try c.decode(TimeInterval.self, forKey: .focusedSeconds)
        completed = try c.decode(Bool.self, forKey: .completed)
        appSwitches = try c.decodeIfPresent(Int.self, forKey: .appSwitches) ?? 0

        if let raw = try c.decodeIfPresent(String.self, forKey: .tomato) {
            tomato = TomatoKind(rawValue: raw)
        } else {
            let old = try legacy.decodeIfPresent([String].self, forKey: .tomatoes) ?? []
            tomato = old.compactMap { TomatoKind(rawValue: $0) }.first
        }

        if let current = try c.decodeIfPresent([String].self, forKey: .tasks) {
            tasks = current
        } else if let single = try legacy.decodeIfPresent(String.self, forKey: .task) {
            tasks = [single]
        } else {
            tasks = []
        }
        tasksDone = try c.decodeIfPresent(Int.self, forKey: .tasksDone)
    }
}

/// Every finished or aborted session, as JSON in Application Support.
@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published private(set) var sessions: [FocusSession] = []
    private let url: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("sessions.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = decoded
        }
    }

    func add(_ session: FocusSession) {
        sessions.append(session)
        save()
    }

    func update(_ session: FocusSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        save()
    }

    // MARK: Totals (all time)

    var totalPoints: Int { sessions.reduce(0) { $0 + $1.points } }
    var totalFocusSeconds: TimeInterval { sessions.reduce(0) { $0 + $1.focusedSeconds } }

    // MARK: Per day — the collection starts empty every morning

    func daySessions(_ day: Date) -> [FocusSession] {
        sessions.filter { AppCalendar.shared.isDate($0.endedAt, inSameDayAs: day) }
    }

    func points(on day: Date) -> Int { daySessions(day).reduce(0) { $0 + $1.points } }

    func focusSeconds(on day: Date) -> TimeInterval {
        daySessions(day).reduce(0) { $0 + $1.focusedSeconds }
    }

    func count(of kind: TomatoKind, on day: Date) -> Int {
        daySessions(day).filter { $0.tomato == kind }.count
    }

    /// Points per calendar day, keyed by start of day — drives the calendar shading.
    var pointsByDay: [Date: Int] {
        sessions.reduce(into: [:]) { result, session in
            result[AppCalendar.shared.startOfDay(for: session.endedAt), default: 0] += session.points
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// One calendar for every day boundary: German, weeks start on Monday.
enum AppCalendar {
    static let shared: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.firstWeekday = 2
        return calendar
    }()
}

// MARK: - Tasks

struct FocusTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var done = false
}

/// What you plan to do in the next session.
@MainActor
final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published private(set) var tasks: [FocusTask]
    private static let key = "tasks"

    private init() {
        let data = UserDefaults.standard.data(forKey: Self.key)
        tasks = data.flatMap { try? JSONDecoder().decode([FocusTask].self, from: $0) } ?? []
    }

    var next: FocusTask? { tasks.first { !$0.done } }
    var hasDone: Bool { tasks.contains { $0.done } }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(FocusTask(title: trimmed))
        save()
    }

    func toggle(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].done.toggle()
        save()
    }

    func markDone(_ ids: Set<UUID>) {
        for index in tasks.indices where ids.contains(tasks[index].id) {
            tasks[index].done = true
        }
        save()
    }

    func remove(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func clearDone() {
        tasks.removeAll { $0.done }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// MARK: - App switches

/// Counts how often another app comes to the front. Needs no permission: it only
/// listens to NSWorkspace activation events, it never looks at the screen.
@MainActor
final class AppSwitchCounter {
    private(set) var count = 0
    private var observer: NSObjectProtocol?

    func reset() { count = 0 }

    func start() {
        guard observer == nil else { return }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != ownPID else { return }
            Task { @MainActor in self?.count += 1 }
        }
    }

    func stop() {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }
}
