import SwiftUI

/// Content of the floating window. The clock scales with the window size;
/// collapsed it shrinks to a single line with clock and play/pause.
@MainActor
struct PanelView: View {
    @ObservedObject var model = PomodoroModel.shared
    @ObservedObject var panel = FloatingPanelController.shared

    var body: some View {
        if panel.isCollapsed { collapsed } else { expanded }
    }

    private var expanded: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                collapseButton(systemImage: "chevron.up", help: "Einklappen")
            }

            clock.frame(maxHeight: .infinity)

            ProgressView(value: model.progress)
            DurationSlider()
            TimerButtons()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collapsed: some View {
        HStack(spacing: 8) {
            clock
            Button { model.toggle() } label: {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.space, modifiers: [])
            collapseButton(systemImage: "chevron.down", help: "Ausklappen")
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Sized far too large, then scaled down to whatever space the window gives it.
    private var clock: some View {
        Text(model.clock)
            .font(.system(size: 300, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.05)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }

    private func collapseButton(systemImage: String, help: String) -> some View {
        Button { panel.toggleCollapsed() } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
    }
}
