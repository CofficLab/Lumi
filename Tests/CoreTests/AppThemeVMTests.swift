#if canImport(XCTest)
import XCTest
import LumiUI
import SwiftUI
@testable import Lumi

final class AppThemeVMTests: XCTestCase {
    @MainActor
    func testInitialThemeUsesSavedThemeWhenAvailable() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor"),
            contribution(pluginOrder: 20, themeId: "saved-app", editorThemeId: "saved-editor")
        ])

        let vm = AppThemeVM(
            registry: registry,
            syncThemes: { _ in },
            loadSelectedThemeID: { "saved-app" },
            saveSelectedThemeID: { _ in },
            postThemeDidChangeNotification: { _, _ in }
        )

        XCTAssertEqual(vm.currentThemeId, "saved-app")
        XCTAssertEqual(registry.selectedThemeId, "saved-app")
    }

    @MainActor
    func testInitialThemeIgnoresUnknownSavedTheme() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor"),
            contribution(pluginOrder: 20, themeId: "other-app", editorThemeId: "other-editor")
        ])

        let vm = AppThemeVM(
            registry: registry,
            syncThemes: { _ in },
            loadSelectedThemeID: { "missing-app" },
            saveSelectedThemeID: { _ in },
            postThemeDidChangeNotification: { _, _ in }
        )

        XCTAssertEqual(vm.currentThemeId, "default-app")
        XCTAssertEqual(registry.selectedThemeId, "default-app")
    }

    @MainActor
    func testSelectingThemePersistsTheme() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor"),
            contribution(pluginOrder: 20, themeId: "other-app", editorThemeId: "other-editor")
        ])
        var savedThemeId: String?
        let vm = AppThemeVM(
            registry: registry,
            syncThemes: { _ in },
            loadSelectedThemeID: { nil },
            saveSelectedThemeID: { savedThemeId = $0 },
            postThemeDidChangeNotification: { _, _ in }
        )

        let didSelect = vm.selectTheme("other-app")

        XCTAssertTrue(didSelect)
        XCTAssertEqual(savedThemeId, "other-app")
    }

    @MainActor
    func testSelectingUnknownThemeReportsFailureWithoutPersisting() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor")
        ])
        var savedThemeIds: [String] = []
        let vm = AppThemeVM(
            registry: registry,
            syncThemes: { _ in },
            loadSelectedThemeID: { nil },
            saveSelectedThemeID: { savedThemeIds.append($0) },
            postThemeDidChangeNotification: { _, _ in }
        )

        let didSelect = vm.selectTheme("missing-app")

        XCTAssertFalse(didSelect)
        XCTAssertEqual(vm.currentThemeId, "default-app")
        XCTAssertEqual(savedThemeIds, [])
    }

    @MainActor
    func testReloadThemesDoesNotRepostUnchangedThemeAfterInitialBroadcast() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor")
        ])
        var savedThemeIds: [String] = []
        var postedChanges: [(themeId: String, editorThemeId: String)] = []
        let vm = AppThemeVM(
            registry: registry,
            syncThemes: { _ in },
            loadSelectedThemeID: { nil },
            saveSelectedThemeID: { savedThemeIds.append($0) },
            postThemeDidChangeNotification: { themeId, editorThemeId in
                postedChanges.append((themeId, editorThemeId))
            }
        )

        vm.reloadThemes()
        vm.reloadThemes()

        XCTAssertEqual(savedThemeIds, ["default-app"])
        XCTAssertEqual(postedChanges.count, 1)
        XCTAssertEqual(postedChanges.first?.themeId, "default-app")
        XCTAssertEqual(postedChanges.first?.editorThemeId, "default-editor")
    }

    @MainActor
    func testPluginsDidLoadReloadsThemesWithInjectedSync() async throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            contribution(pluginOrder: 10, themeId: "default-app", editorThemeId: "default-editor")
        ])
        var syncCount = 0
        let vm = AppThemeVM(
            registry: registry,
            syncThemes: { _ in syncCount += 1 },
            loadSelectedThemeID: { nil },
            saveSelectedThemeID: { _ in },
            postThemeDidChangeNotification: { _, _ in }
        )

        NotificationCenter.default.post(name: .pluginsDidLoad, object: nil)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(vm.currentThemeId, "default-app")
        XCTAssertEqual(syncCount, 2)
    }

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
