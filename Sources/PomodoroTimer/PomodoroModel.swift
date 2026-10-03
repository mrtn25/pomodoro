import AppKit
import Combine

/// Countdown and session lifecycle. Running time hangs on an absolute end date,
/// so the countdown stays correct through sleep, app-nap and relaunch.
///
/// Cycle: focus → (completed) automatic 5-min break → "next session". A focus
/// session starts with the first Start from a full timer and ends when the
/// countdown hits zero (completed, earns a tomato) or on reset (aborted, logged
/// from one minute on, earns nothing). Each one is logged in `SessionStore`.
@MainActor
final class PomodoroModel: ObservableObject {
    static let shared = PomodoroModel()

    enum Mode: String { case focus, rest }

    /// Slider range for the focus length.
    static let minuteRange: ClosedRange<Double> = 1...60
    static let breakLength: TimeInterval = 5 * 60

    @Published private(set) var mode: Mode
    @Published private(set) var focusDuration: TimeInterval
    @Published private(set) var endsAt: Date?
    @Published private(set) var pausedRemaining: TimeInterval
    @Published private(set) var sessionStartedAt: Date?
    /// The break ran out; the timer page offers "Nächste Session starten".
    @Published private(set) var breakFinished: Bool
    /// The focus session that just ended — reward and task review, until the next start.
    @Published private(set) var lastSession: FocusSession?
    /// The tasks `lastSession` was planned with, for the review.
    @Published private(set) var reviewTasks: [FocusTask] = []
    @Published private(set) var now = Date()

    /// Tasks that were open when the running session started.
    private var sessionTasks: [FocusTask]
    private var ticker: Timer?
    private let switches = AppSwitchCounter()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let mode = "pomodoro.mode"
        static let duration = "pomodoro.duration"
        static let endsAt = "pomodoro.endsAt"
        static let pausedRemaining = "pomodoro.pausedRemaining"
        static let sessionStartedAt = "pomodoro.sessionStartedAt"
        static let sessionTasks = "pomodoro.sessionTasks"
        static let breakFinished = "pomodoro.breakFinished"
    }

    private init() {
        // Locals only: a class may not touch `self` before every stored property is set.
        let stored = UserDefaults.standard
        let storedDuration = stored.double(forKey: Key.duration)
        let initialDuration = storedDuration > 0 ? storedDuration : 25 * 60
        let storedMode = Mode(rawValue: stored.string(forKey: Key.mode) ?? "") ?? .focus
        mode = storedMode
        focusDuration = initialDuration
        pausedRemaining = stored.object(forKey: Key.pausedRemaining) as? Double
            ?? (storedMode == .focus ? initialDuration : Self.breakLength)
        endsAt = stored.object(forKey: Key.endsAt) as? Date
        sessionStartedAt = stored.object(forKey: Key.sessionStartedAt) as? Date
        breakFinished = stored.bool(forKey: Key.breakFinished)
        sessionTasks = stored.data(forKey: Key.sessionTasks)
            .flatMap { try? JSONDecoder().decode([FocusTask].self, from: $0) } ?? []

        if let end = endsAt {
            if end <= Date() {
                // Ran out while the app was closed: log it, skip the alarm and the break.
                if mode == .focus {
                    reviewTasks = sessionTasks
                    lastSession = record(completed: true, focused: focusDuration)
                }
                goIdle(breakFinished: false)
            } else {
                if mode == .focus { switches.start() }
                startTicker()
            }
        }
    }

    // MARK: State

    var isRunning: Bool { endsAt != nil }
    var hasSession: Bool { sessionStartedAt != nil }
    /// Something is counting or paused mid-way: show the clock in the menu bar.
    var isActive: Bool { hasSession || mode == .rest }
    var minutes: Int { Int(focusDuration / 60) }
    var duration: TimeInterval { mode == .focus ? focusDuration : Self.breakLength }
    var reviewPending: Bool { lastSession?.needsReview ?? false }

    var remaining: TimeInterval {
        guard let endsAt else { return pausedRemaining }
        return max(0, endsAt.timeIntervalSince(now))
    }

    var progress: Double { duration > 0 ? min(1, 1 - remaining / duration) : 0 }

    var clock: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Actions

    /// Sets the focus length. Only between sessions — the slider is hidden otherwise.
    func setMinutes(_ minutes: Int) {
        guard mode == .focus, !hasSession else { return }
        let clamped = min(max(Double(minutes), Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        focusDuration = clamped * 60
        pausedRemaining = focusDuration
        save()
    }

    func toggle() { isRunning ? pause() : start() }

    /// Starts or resumes the current phase; a fresh start in focus opens a new session.
    func start() {
        guard !isRunning else { return }
        now = Date()
        if mode == .focus && sessionStartedAt == nil {
            pausedRemaining = focusDuration
            sessionStartedAt = now
            sessionTasks = TaskStore.shared.tasks.filter { !$0.done }
            switches.reset()
            lastSession = nil
            reviewTasks = []
            breakFinished = false
        }
        endsAt = now.addingTimeInterval(pausedRemaining)
        if mode == .focus { switches.start() }
        startTicker()
        save()
        if mode == .focus { Sound.start() }
    }

    func pause() {
        guard isRunning else { return }
        now = Date()
        pausedRemaining = remaining
        endsAt = nil
        switches.stop()
        stopTicker()
        save()
    }

    /// Ends the break early and starts the next focus session right away.
    func startNextSession() {
        if mode == .rest { goIdle(breakFinished: false) }
        start()
    }

    /// In focus: ends the session early (logged from one minute on). In a break: ends the break.
    func reset() {
        now = Date()
        if mode == .focus && hasSession {
            let focused = focusDuration - remaining
            if focused >= 60 {
                lastSession = record(completed: false, focused: focused)
            } else {
                endSession()
            }
        }
        goIdle(breakFinished: false)
    }

    /// Confirms which planned tasks got done; only those count for the bonus, once per session.
    func review(done ids: Set<UUID>) {
        guard var session = lastSession, session.needsReview else { return }
        let planned = Set(reviewTasks.map(\.id))
        let confirmed = ids.intersection(planned)
        session.tasksDone = confirmed.count
        SessionStore.shared.update(session)
        TaskStore.shared.markDone(confirmed)
        lastSession = session
    }

    // MARK: Internals

    private func tick() {
        now = Date()
        guard let endsAt, now >= endsAt else { return }
        if mode == .focus {
            completeFocus()
        } else {
            completeBreak()
        }
    }

    private func completeFocus() {
        reviewTasks = sessionTasks
        lastSession = record(completed: true, focused: focusDuration)
        Sound.end()
        NSApp.requestUserAttention(.informationalRequest)
        // Straight into the break.
        mode = .rest
        now = Date()
        endsAt = now.addingTimeInterval(Self.breakLength)
        save()
    }

    private func completeBreak() {
        goIdle(breakFinished: true)
        Sound.breakOver()
    }

    /// Back to a full, stopped focus timer.
    private func goIdle(breakFinished finished: Bool) {
        mode = .focus
        endsAt = nil
        pausedRemaining = focusDuration
        breakFinished = finished
        stopTicker()
        save()
    }

    private func record(completed: Bool, focused: TimeInterval) -> FocusSession? {
        guard let started = sessionStartedAt else { return nil }
        let session = FocusSession(
            startedAt: started,
            endedAt: Date(),
            plannedMinutes: minutes,
            focusedSeconds: focused,
            completed: completed,
            appSwitches: switches.count,
            tomato: completed ? TomatoRules.tomato(forMinutes: minutes) : nil,
            tasks: sessionTasks.map(\.title)
        )
        SessionStore.shared.add(session)
        endSession()
        return session
    }

    private func endSession() {
        switches.stop()
        sessionStartedAt = nil
        sessionTasks = []
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common keeps it ticking while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func save() {
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(focusDuration, forKey: Key.duration)
        defaults.set(pausedRemaining, forKey: Key.pausedRemaining)
        defaults.set(endsAt, forKey: Key.endsAt)
        defaults.set(sessionStartedAt, forKey: Key.sessionStartedAt)
        defaults.set(breakFinished, forKey: Key.breakFinished)
        defaults.set(try? JSONEncoder().encode(sessionTasks), forKey: Key.sessionTasks)
    }
}

enum Sound {
    static func start() { NSSound(named: "Pop")?.play() }
    static func end() { NSSound(named: "Glass")?.play() }
    static func breakOver() { NSSound(named: "Ping")?.play() }
}
