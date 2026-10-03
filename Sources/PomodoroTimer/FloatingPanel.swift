import AppKit
import SwiftUI

/// Small always-on-top window that floats above every app and every Space.
/// Freely resizable; collapsing shrinks it to one line and expanding restores
/// the last expanded size, keeping the top edge in place.
@MainActor
final class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = FloatingPanelController()

    @Published private(set) var isVisible = false
    @Published private(set) var isCollapsed: Bool

    private var panel: NSPanel?
    private let defaults = UserDefaults.standard

    private static let collapsedSize = NSSize(width: 210, height: 44)
    private static let collapsedMin = NSSize(width: 170, height: 40)
    private static let expandedDefault = NSSize(width: 300, height: 400)
    private static let expandedMin = NSSize(width: 260, height: 340)

    private enum Key {
        static let collapsed = "panel.collapsed"
        static let expandedWidth = "panel.expandedWidth"
        static let expandedHeight = "panel.expandedHeight"
    }

    override init() {
        isCollapsed = UserDefaults.standard.bool(forKey: Key.collapsed)
        super.init()
    }

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

    func toggleCollapsed() {
        guard let panel else { return }
        if !isCollapsed { rememberExpandedSize(panel.contentRect(forFrameRect: panel.frame).size) }
        isCollapsed.toggle()
        defaults.set(isCollapsed, forKey: Key.collapsed)
        applySize(to: panel)
    }

    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel, !isCollapsed else { return }
        rememberExpandedSize(panel.contentRect(forFrameRect: panel.frame).size)
    }

    private var expandedSize: NSSize {
        let w = defaults.double(forKey: Key.expandedWidth)
        let h = defaults.double(forKey: Key.expandedHeight)
        guard w > 0, h > 0 else { return Self.expandedDefault }
        return NSSize(width: max(w, Self.expandedMin.width), height: max(h, Self.expandedMin.height))
    }

    private func rememberExpandedSize(_ size: NSSize) {
        defaults.set(size.width, forKey: Key.expandedWidth)
        defaults.set(size.height, forKey: Key.expandedHeight)
    }

    /// Resizes to the current mode while keeping the window's top edge fixed.
    private func applySize(to panel: NSPanel) {
        let size = isCollapsed ? Self.collapsedSize : expandedSize
        panel.contentMinSize = isCollapsed ? Self.collapsedMin : Self.expandedMin
        let top = panel.frame.maxY
        var frame = panel.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: panel.frame.minX, y: top - frame.height)
        panel.setFrame(frame, display: true, animate: true)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.expandedDefault),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pomodoro"
        // Clean white window: no visible title bar, no traffic lights. Closing lives in the ••• menu.
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.backgroundColor = .white
        panel.appearance = NSAppearance(named: .aqua)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self

        let hosting = NSHostingView(rootView: PanelRoot())
        // The user sizes the window, not the SwiftUI content.
        hosting.sizingOptions = []
        panel.contentView = hosting

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - 260, y: visible.maxY - 20))
        }
        // Restores the last position (and size) if there is one, then fits the current mode.
        panel.setFrameUsingName("PomodoroPanel")
        panel.setFrameAutosaveName("PomodoroPanel")
        applySize(to: panel)
        return panel
    }
}

@MainActor
private struct PanelRoot: View {
    @ObservedObject private var panel = FloatingPanelController.shared

    var body: some View {
        if panel.isCollapsed {
            CollapsedBar()
        } else {
            MainView(placement: .panel)
        }
    }
}
