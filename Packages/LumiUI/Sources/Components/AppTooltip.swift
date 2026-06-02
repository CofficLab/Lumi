import SwiftUI

public extension View {
    func appTooltip(_ text: LocalizedStringKey) -> some View {
        help(text)
    }

    func appTooltip(_ text: LocalizedStringKey, shortcut: KeyboardShortcut?) -> some View {
        Group {
            if let shortcut {
                help(Text(text) + Text(" (\(shortcut.appDisplayText))"))
            } else {
                help(text)
            }
        }
    }
}

extension KeyboardShortcut {
    var appDisplayText: String {
        modifierDisplayText + keyDisplayText
    }

    private var modifierDisplayText: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }

        return parts.joined()
    }

    private var keyDisplayText: String {
        switch key.character {
        case "\r": return "↩"
        case "\u{1B}": return "Esc"
        case " ": return "Space"
        case "\u{7F}": return "⌫"
        case "\u{8}": return "⌦"
        case "\t": return "⇥"
        default:
            return String(key.character).uppercased()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Hover me")
            .appTooltip("Simple tooltip")
        Text("With shortcut")
            .appTooltip("Save file", shortcut: .init("s", modifiers: .command))
    }
    .padding()
    .frame(width: 300)
    .background(Color.gray.opacity(0.15))
}
