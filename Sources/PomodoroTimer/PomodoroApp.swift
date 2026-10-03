import AppKit
import SwiftUI

/// Menu-bar Pomodoro timer: a tomato (plus the countdown) in the menu bar, the app
/// in its dropdown, and an optional floating window that stays above all apps.
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
            MainView(placement: .menu)
        } label: {
            // Tomato always, the countdown next to it while a session is on.
            HStack(spacing: 4) {
                Image(nsImage: TomatoArt.menuBarIcon)
                if model.hasSession {
                    Text(model.clock).monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
