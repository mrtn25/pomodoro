import AppKit
import SwiftUI

/// The one palette: tomato red for everything active, leaf green as the accent.
enum Theme {
    static let red = Color(red: 0.87, green: 0.20, blue: 0.16)
    static let green = Color(red: 0.24, green: 0.58, blue: 0.24)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let muted = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let hairline = Color(red: 0.92, green: 0.92, blue: 0.93)
    static let background = Color.white
}

/// Loads the tomato stickers: from Contents/Resources/Tomatoes in the installed app,
/// from the source tree when started with `swift run`.
@MainActor
enum TomatoArt {
    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage {
        if let cached = cache[name] { return cached }
        let sourceTree = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PomodoroTimer
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Resources/Tomatoes/\(name).png")
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Tomatoes") ?? sourceTree
        let image = NSImage(contentsOf: url)
            ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
            ?? NSImage()
        cache[name] = image
        return image
    }

    /// 18 pt tomato for the menu bar.
    static let menuBarIcon: NSImage = {
        let icon = (TomatoArt.image("zen").copy() as? NSImage) ?? NSImage()
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }()
}

func formatFocus(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
}
