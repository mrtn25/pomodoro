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

    private static let collapsedSize = NSSize(width: 190, height: 44)
    private static let collapsedMin = NSSize(width: 150, height: 36)
    private static let expandedDefault = NSSize(width: 240, height: 250)
    private static let expandedMin = NSSize(width: 200, height: 210)

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
        return w > 0 && h > 0 ? NSSize(width: w, height: h) : Self.expandedDefault
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
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
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

        let hosting = NSHostingView(rootView: PanelView())
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
