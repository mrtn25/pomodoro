import AppKit
import SwiftUI

/// Shared controls for the menu-bar dropdown and the floating panel.
@MainActor
struct ControlsView: View {
    @ObservedObject var model = PomodoroModel.shared
    @ObservedObject var panel = FloatingPanelController.shared
    var compact = false

    var body: some View {
        VStack(spacing: 12) {
            Text(model.clock)
                .font(.system(size: compact ? 36 : 44, weight: .semibold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: model.progress)

            Picker("", selection: presetBinding) {
                ForEach(PomodoroModel.presets) { preset in
                    Text("\(preset.label) · \(preset.minutes) min").tag(preset.minutes)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

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

            if !compact {
                Divider()
                Toggle("Schwebendes Fenster", isOn: Binding(
                    get: { panel.isVisible },
                    set: { $0 ? panel.show() : panel.hide() }
                ))
                Button("Beenden") { NSApp.terminate(nil) }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .frame(width: compact ? 220 : 260)
    }

    private var presetBinding: Binding<Int> {
        Binding(
            get: { Int(model.duration / 60) },
            set: { model.select(minutes: $0) }
        )
    }
}
