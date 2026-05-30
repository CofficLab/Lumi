#if canImport(XCTest)
import AppKit
import CodeEditSourceEditor
import XCTest
@testable import EditorService

@MainActor
private final class MockEditorThemeContributor: SuperEditorThemeContributor {
    let id = "delayed-theme"
    let displayName = "Delayed Theme"
    let icon: String? = nil
    let isDark = true

    func createTheme() -> EditorTheme {
        makeTheme(background: .systemRed)
    }
}

@MainActor
private final class ThemeRegistrationGate {
    var isEnabled = false
}

@MainActor
final class EditorStateThemeTests: XCTestCase {
    func testSameThemeNotificationRefreshesThemeAfterContributorRegistration() async {
        let previousEnvironment = EditorHostEnvironment.current
        let previousRegisterEditorThemeContributors = EditorSettingsLifecycle.registerEditorThemeContributors
        defer {
            EditorHostEnvironment.configure(previousEnvironment)
            EditorSettingsLifecycle.registerEditorThemeContributors = previousRegisterEditorThemeContributors
        }

        let themeDidChange = Notification.Name("EditorStateThemeTests.themeDidChange.\(UUID().uuidString)")
        let notifications = EditorHostEnvironment.Notifications(themeDidChange: themeDidChange)
        EditorHostEnvironment.configure(EditorHostEnvironment(notifications: notifications))

        let themeRegistrationGate = ThemeRegistrationGate()
        EditorSettingsLifecycle.registerEditorThemeContributors = { registry in
            guard themeRegistrationGate.isEnabled else { return }
            registry.registerThemeContributor(MockEditorThemeContributor())
        }

        let state = EditorState(editorExtensions: EditorExtensionRegistry())

        NotificationCenter.default.post(
            name: themeDidChange,
            object: nil,
            userInfo: ["editorThemeId": "delayed-theme"]
        )
        await Task.yield()

        XCTAssertEqual(state.currentThemeId, "delayed-theme")
        XCTAssertNotEqual(redComponent(state.currentTheme?.background), redComponent(.systemRed))

        themeRegistrationGate.isEnabled = true
        NotificationCenter.default.post(
            name: themeDidChange,
            object: nil,
            userInfo: ["editorThemeId": "delayed-theme"]
        )
        await Task.yield()

        XCTAssertEqual(state.currentThemeId, "delayed-theme")
        XCTAssertEqual(redComponent(state.currentTheme?.background), redComponent(.systemRed), accuracy: 0.001)
    }
}

private func makeTheme(background: NSColor) -> EditorTheme {
    let text = EditorTheme.Attribute(color: .white)
    return EditorTheme(
        text: text,
        insertionPoint: .white,
        invisibles: text,
        background: background,
        lineHighlight: .black,
        selection: .selectedTextBackgroundColor,
        keywords: text,
        commands: text,
        types: text,
        attributes: text,
        variables: text,
        values: text,
        numbers: text,
        strings: text,
        characters: text,
        comments: text
    )
}

private func redComponent(_ color: NSColor?) -> CGFloat {
    color?.usingColorSpace(.deviceRGB)?.redComponent ?? -1
}
#endif
