import SwiftUI
import Testing
@testable import LumiUI

struct AppTooltipTests {
    @Test
    func shortcutDisplayTextIncludesLiteralKey() {
        let shortcut = KeyboardShortcut("s", modifiers: [.command])

        #expect(shortcut.appDisplayText == "⌘S")
    }

    @Test
    func shortcutDisplayTextHandlesDefaultActions() {
        #expect(KeyboardShortcut.defaultAction.appDisplayText == "↩")
        #expect(KeyboardShortcut.cancelAction.appDisplayText == "Esc")
    }

    @Test
    func shortcutDisplayTextOrdersModifiersConsistently() {
        let shortcut = KeyboardShortcut("p", modifiers: [.shift, .option, .command])

        #expect(shortcut.appDisplayText == "⌘⌥⇧P")
    }
}
