import SwiftUI
import Testing
@testable import LumiUI

private struct TestTheme: LumiUITheme {
    let id = "test-theme"
    let name = "Test Theme"

    let primary = Color.red
    let primarySecondary = Color.orange

    let textPrimary = Color.black
    let textSecondary = Color.gray
    let textTertiary = Color.secondary
    let textDisabled = Color.gray.opacity(0.5)

    let background = Color.white
    let surface = Color.white
    let elevatedSurface = Color.white
    let overlay = Color.gray.opacity(0.1)
    let divider = Color.gray.opacity(0.2)

    let success = Color.green
    let warning = Color.yellow
    let error = Color.red
    let info = Color.blue
}

struct LumiUIThemeTests {
    @Test
    @MainActor
    func defaultThemeIsAvailable() {
        LumiUI.setTheme(LumiDefaultTheme())

        #expect(LumiUI.currentTheme.id == "lumi-default")
        #expect(LumiUI.currentTheme.name == "Lumi Default")
    }

    @Test
    @MainActor
    func setThemeReplacesCurrentTheme() {
        LumiUI.setTheme(TestTheme())
        defer { LumiUI.setTheme(LumiDefaultTheme()) }

        #expect(LumiUI.currentTheme.id == "test-theme")
        #expect(LumiUI.currentTheme.name == "Test Theme")
    }
}
