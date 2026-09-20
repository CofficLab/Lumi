#if canImport(XCTest)
import AppKit
import EditorSource
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
    func testThemeObserverCancellationStopsCallbacks() async {
        let previousEnvironment = EditorHostEnvironment.current
        defer {
            EditorHostEnvironment.configure(previousEnvironment)
        }

        let themeDidChange = Notification.Name("EditorStateThemeTests.cancellation.\(UUID().uuidString)")
        let notifications = EditorHostEnvironment.Notifications(themeDidChange: themeDidChange)
        EditorHostEnvironment.configure(EditorHostEnvironment(notifications: notifications))

        let configController = EditorConfigController()
        var receivedThemeIDs: [String] = []
        let firstCallback = expectation(description: "first theme callback")
        var cancelledCallback: XCTestExpectation?
        let cancellable = configController.observeThemeChanges { themeId, _ in
            receivedThemeIDs.append(themeId)
            if receivedThemeIDs.count == 1 {
                firstCallback.fulfill()
            } else {
                cancelledCallback?.fulfill()
            }
        }

        NotificationCenter.default.post(
            name: themeDidChange,
            object: nil,
            userInfo: ["editorThemeId": "first-theme"]
        )
        await fulfillment(of: [firstCallback], timeout: 1)
        XCTAssertEqual(receivedThemeIDs, ["first-theme"])

        let noCallbackAfterCancel = expectation(description: "cancelled observer callback")
        noCallbackAfterCancel.isInverted = true
        cancelledCallback = noCallbackAfterCancel
        cancellable.cancel()

        NotificationCenter.default.post(
            name: themeDidChange,
            object: nil,
            userInfo: ["editorThemeId": "second-theme"]
        )
        await fulfillment(of: [noCallbackAfterCancel], timeout: 0.2)
        XCTAssertEqual(receivedThemeIDs, ["first-theme"])
    }

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
        await waitUntil("theme id updates to delayed-theme") {
            state.currentThemeId == "delayed-theme"
        }

        XCTAssertEqual(state.currentThemeId, "delayed-theme")
        XCTAssertNotEqual(redComponent(state.currentTheme?.background), redComponent(.systemRed))

        themeRegistrationGate.isEnabled = true
        NotificationCenter.default.post(
            name: themeDidChange,
            object: nil,
            userInfo: ["editorThemeId": "delayed-theme"]
        )
        await waitUntil("theme refreshes after contributor registration") {
            abs(redComponent(state.currentTheme?.background) - redComponent(.systemRed)) < 0.001
        }

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

@MainActor
private func waitUntil(
    _ description: String,
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for \(description)", file: file, line: line)
}
#endif
