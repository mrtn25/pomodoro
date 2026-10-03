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
    let tomatoes: [TomatoKind]
    /// The open task at session start, if any.
    let task: String?
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
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func count(of kind: TomatoKind) -> Int {
        sessions.reduce(0) { $0 + $1.tomatoes.filter { $0 == kind }.count }
    }

    var totalTomatoes: Int { sessions.reduce(0) { $0 + $1.tomatoes.count } }
    var totalFocusSeconds: TimeInterval { sessions.reduce(0) { $0 + $1.focusedSeconds } }

    func focusSeconds(on day: Date) -> TimeInterval {
        sessions.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.focusedSeconds }
    }

    func tomatoes(on day: Date) -> Int {
        sessions.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.tomatoes.count }
    }
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
