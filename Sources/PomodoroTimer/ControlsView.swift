import AppKit
import SwiftUI

/// Menu-bar dropdown: clock, length slider, start/pause/reset and the panel switch.
@MainActor
struct ControlsView: View {
    @ObservedObject var model = PomodoroModel.shared
    @ObservedObject var panel = FloatingPanelController.shared

    var body: some View {
        VStack(spacing: 12) {
            Text(model.clock)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: model.progress)
            DurationSlider()
            TimerButtons()

            Divider()
            Toggle("Schwebendes Fenster", isOn: Binding(
                get: { panel.isVisible },
                set: { $0 ? panel.show() : panel.hide() }
            ))
            Button("Beenden") { NSApp.terminate(nil) }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 260)
    }
}

/// Countdown length, 1–60 minutes. Locked while the timer runs.
@MainActor
struct DurationSlider: View {
    @ObservedObject var model = PomodoroModel.shared

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Dauer").foregroundStyle(.secondary)
                Spacer()
                Text("\(model.minutes) min").monospacedDigit()
            }
            .font(.callout)

            Slider(
                value: Binding(
                    get: { Double(model.minutes) },
                    set: { model.setMinutes(Int($0.rounded())) }
                ),
                in: PomodoroModel.minuteRange,
                step: 1
            )
            .disabled(model.isRunning)
        }
        .help(model.isRunning ? "Zum Ändern erst pausieren" : "Länge des Timers")
    }
}

@MainActor
struct TimerButtons: View {
    @ObservedObject var model = PomodoroModel.shared

    var body: some View {
        HStack {
            Button { model.toggle() } label: {
                Label(model.isRunning ? "Pause" : "Start",
                      systemImage: model.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)

            Button { model.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Zurücksetzen")
        }
    }
}
