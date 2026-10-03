import AppKit
import SwiftUI

/// Menu-bar Pomodoro timer: the countdown lives in the menu bar, the dropdown
/// holds the controls, and an optional floating panel stays above all apps.
@main
@MainActor
struct PomodoroApp: App {
    @StateObject private var model = PomodoroModel.shared

    init() {
        // Menu-bar only: no Dock icon, no app menu.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ControlsView()
        } label: {
            if model.isTouched {
                Text(model.clock).monospacedDigit()
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
