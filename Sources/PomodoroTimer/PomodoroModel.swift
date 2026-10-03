import AppKit
import Combine

/// Countdown state. Like the web timer, running time hangs on an absolute end date,
/// so the countdown stays correct through sleep, app-nap and relaunch.
@MainActor
final class PomodoroModel: ObservableObject {
    static let shared = PomodoroModel()

    /// Slider range for the countdown length.
    static let minuteRange: ClosedRange<Double> = 1...60

    @Published private(set) var duration: TimeInterval
    @Published private(set) var endsAt: Date?
    @Published private(set) var pausedRemaining: TimeInterval
    @Published private(set) var now = Date()

    private var ticker: Timer?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let duration = "pomodoro.duration"
        static let endsAt = "pomodoro.endsAt"
        static let pausedRemaining = "pomodoro.pausedRemaining"
    }

    private init() {
        // Locals only: a class may not touch `self` before every stored property is set.
        let stored = UserDefaults.standard
        let storedDuration = stored.double(forKey: Key.duration)
        let initialDuration = storedDuration > 0 ? storedDuration : 25 * 60
        duration = initialDuration
        pausedRemaining = stored.object(forKey: Key.pausedRemaining) as? Double ?? initialDuration
        endsAt = stored.object(forKey: Key.endsAt) as? Date

        if let end = endsAt {
            if end <= Date() {
                // Ran out while the app was closed: show 0:00, no late alarm.
                endsAt = nil
                pausedRemaining = 0
                save()
            } else {
                startTicker()
            }
        }
    }

    var isRunning: Bool { endsAt != nil }

    var remaining: TimeInterval {
        guard let endsAt else { return pausedRemaining }
        return max(0, endsAt.timeIntervalSince(now))
    }

    var progress: Double { duration > 0 ? min(1, 1 - remaining / duration) : 0 }

    /// True once the timer has been started at least once since the last reset.
    var isTouched: Bool { isRunning || remaining < duration }

    var clock: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var minutes: Int { Int(duration / 60) }

    /// Sets a new length and resets to it. Ignored while running.
    func setMinutes(_ minutes: Int) {
        guard !isRunning else { return }
        let clamped = min(max(Double(minutes), Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        duration = clamped * 60
        reset()
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        let left = pausedRemaining > 0 ? pausedRemaining : duration
        now = Date()
        endsAt = now.addingTimeInterval(left)
        startTicker()
        save()
    }

    func pause() {
        guard isRunning else { return }
        now = Date()
        pausedRemaining = remaining
        endsAt = nil
        stopTicker()
        save()
    }

    func reset() {
        endsAt = nil
        pausedRemaining = duration
        stopTicker()
        save()
    }

    private func tick() {
        now = Date()
        if let endsAt, now >= endsAt { finish() }
    }

    private func finish() {
        endsAt = nil
        pausedRemaining = 0
        stopTicker()
        save()
        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.informationalRequest)
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
    }
}
