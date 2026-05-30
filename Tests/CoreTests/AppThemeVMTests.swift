#if canImport(XCTest)
import XCTest
import LumiUI
import SwiftUI
@testable import Lumi

final class AppThemeVMTests: XCTestCase {
    @MainActor
    func testEditorThemeIDReturnsContributionEditorTheme() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "app-theme", editorThemeId: "editor-theme")
        ])

        XCTAssertEqual(
            AppThemeVM.editorThemeID(for: "app-theme", registry: registry),
            "editor-theme"
        )
    }

    @MainActor
    func testEditorThemeIDFallsBackToDefaultEditorTheme() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor"),
            contribution(pluginOrder: 20, themeId: "other-app", editorThemeId: "other-editor")
        ])

        XCTAssertEqual(
            AppThemeVM.editorThemeID(for: "missing-app", registry: registry),
            "default-editor"
        )
    }

    private func contribution(
        pluginOrder: Int,
        themeId: String,
        editorThemeId: String
    ) -> LumiUIThemeContribution {
        LumiUIThemeContribution(
            sortKey: ThemeSortKey(pluginOrder: pluginOrder, themeId: themeId),
            chromeTheme: MockChromeTheme(id: themeId),
            editorThemeId: editorThemeId
        )
    }
}

private struct MockChromeTheme: LumiAppChromeTheme {
    let identifier: String

    init(id: String) {
        identifier = id
    }

    var displayName: String { identifier }
    var compactName: String { identifier }
    var description: String { "Mock theme \(identifier)" }
    var iconName: String { "circle.fill" }
    var iconColor: Color { .blue }
    var appearanceKind: ThemeAppearanceKind { .dark }

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (.blue, .blue.opacity(0.8), .blue.opacity(0.6))
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (.black, .gray, .white)
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.blue.opacity(0.1), .blue.opacity(0.2), .blue.opacity(0.3))
    }
}
#endif
