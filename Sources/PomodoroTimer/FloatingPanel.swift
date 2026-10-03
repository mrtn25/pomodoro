import AppKit
import SwiftUI

/// Small always-on-top window that floats above every app and every Space.
@MainActor
final class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = FloatingPanelController()

    @Published private(set) var isVisible = false
    private var panel: NSPanel?

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 170),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pomodoro"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ControlsView(compact: true))

        if !panel.setFrameUsingName("PomodoroPanel"), let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 240, y: frame.maxY - 200))
        }
        panel.setFrameAutosaveName("PomodoroPanel")
        return panel
    }
}
