import AppKit
import Combine

/// Countdown and session lifecycle. Running time hangs on an absolute end date,
/// so the countdown stays correct through sleep, app-nap and relaunch.
///
/// A session starts with the first Start from a full timer and ends either when
/// the countdown hits zero (completed) or on reset (aborted). Each one is logged
/// in `SessionStore` together with the tomatoes it earned.
@MainActor
final class PomodoroModel: ObservableObject {
    static let shared = PomodoroModel()

    /// Slider range for the countdown length.
    static let minuteRange: ClosedRange<Double> = 1...60

    @Published private(set) var duration: TimeInterval
    @Published private(set) var endsAt: Date?
    @Published private(set) var pausedRemaining: TimeInterval
    @Published private(set) var sessionStartedAt: Date?
    /// The session that just ended — shown as reward until the next start.
    @Published private(set) var lastSession: FocusSession?
    @Published private(set) var now = Date()

    private var sessionTask: String?
    private var ticker: Timer?
    private let switches = AppSwitchCounter()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let duration = "pomodoro.duration"
        static let endsAt = "pomodoro.endsAt"
        static let pausedRemaining = "pomodoro.pausedRemaining"
        static let sessionStartedAt = "pomodoro.sessionStartedAt"
        static let sessionTask = "pomodoro.sessionTask"
    }

    private init() {
        // Locals only: a class may not touch `self` before every stored property is set.
        let stored = UserDefaults.standard
        let storedDuration = stored.double(forKey: Key.duration)
        let initialDuration = storedDuration > 0 ? storedDuration : 25 * 60
        duration = initialDuration
        pausedRemaining = stored.object(forKey: Key.pausedRemaining) as? Double ?? initialDuration
        endsAt = stored.object(forKey: Key.endsAt) as? Date
        sessionStartedAt = stored.object(forKey: Key.sessionStartedAt) as? Date
        sessionTask = stored.string(forKey: Key.sessionTask)

        if let end = endsAt {
            if end <= Date() {
                // Ran out while the app was closed: log it, but no late alarm.
                complete(silently: true)
            } else {
                switches.start()
                startTicker()
            }
        }
    }

    // MARK: State

    var isRunning: Bool { endsAt != nil }
    var hasSession: Bool { sessionStartedAt != nil }
    var minutes: Int { Int(duration / 60) }

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

    /// Sets a new length. Only between sessions — the slider is hidden during one.
    func setMinutes(_ minutes: Int) {
        guard !hasSession else { return }
        let clamped = min(max(Double(minutes), Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        duration = clamped * 60
        pausedRemaining = duration
        save()
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        now = Date()
        if sessionStartedAt == nil {
            pausedRemaining = duration
            sessionStartedAt = now
            sessionTask = TaskStore.shared.next?.title
            switches.reset()
            lastSession = nil
        }
        endsAt = now.addingTimeInterval(pausedRemaining)
        switches.start()
        startTicker()
        save()
        Sound.start()
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

    /// Ends the session early. Anything from one minute of focus on is logged.
    func reset() {
        now = Date()
        if hasSession {
            let focused = duration - remaining
            if focused >= 60 {
                lastSession = record(completed: false, focused: focused)
            } else {
                endSession()
            }
        }
        endsAt = nil
        pausedRemaining = duration
        stopTicker()
        save()
    }

    // MARK: Internals

    private func tick() {
        now = Date()
        if let endsAt, now >= endsAt { complete(silently: false) }
    }

    private func complete(silently: Bool) {
        lastSession = record(completed: true, focused: duration)
        endsAt = nil
        pausedRemaining = duration
        stopTicker()
        save()
        if !silently {
            Sound.end()
            NSApp.requestUserAttention(.informationalRequest)
        }
    }

    private func record(completed: Bool, focused: TimeInterval) -> FocusSession? {
        guard let started = sessionStartedAt else { return nil }
        let store = SessionStore.shared
        let session = FocusSession(
            startedAt: started,
            endedAt: Date(),
            plannedMinutes: minutes,
            focusedSeconds: focused,
            completed: completed,
            appSwitches: switches.count,
            tomatoes: TomatoRules.awards(
                completed: completed,
                plannedMinutes: minutes,
                focusedSeconds: focused,
                focusTodayBefore: store.focusSeconds(on: Date())
            ),
            task: sessionTask
        )
        store.add(session)
        endSession()
        return session
    }

    private func endSession() {
        switches.stop()
        sessionStartedAt = nil
        sessionTask = nil
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
        defaults.set(duration, forKey: Key.duration)
        defaults.set(pausedRemaining, forKey: Key.pausedRemaining)
        defaults.set(endsAt, forKey: Key.endsAt)
        defaults.set(sessionStartedAt, forKey: Key.sessionStartedAt)
        defaults.set(sessionTask, forKey: Key.sessionTask)
    }
}

enum Sound {
    static func start() { NSSound(named: "Pop")?.play() }
    static func end() { NSSound(named: "Glass")?.play() }
}
