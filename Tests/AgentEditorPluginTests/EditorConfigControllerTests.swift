#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorConfigControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        EditorConfigStore.removeValue(forKey: EditorConfigStore.fontSizeKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.tabWidthKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.useSpacesKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.formatOnSaveKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.organizeImportsOnSaveKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.fixAllOnSaveKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.trimTrailingWhitespaceOnSaveKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.insertFinalNewlineOnSaveKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.wrapLinesKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.showMinimapKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.showGutterKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.showFoldingRibbonKey)
        EditorConfigStore.removeValue(forKey: EditorConfigStore.themeNameKey)
        EditorConfigStore.removeValue(forKey: "scopedOverrides.v1")
    }

    func testPersistConfigRoundTripsSnapshotValues() {
        let controller = EditorConfigController()
        let snapshot = EditorConfigSnapshot(
            fontSize: 15,
            tabWidth: 2,
            useSpaces: false,
            formatOnSave: true,
            organizeImportsOnSave: true,
            fixAllOnSave: false,
            trimTrailingWhitespaceOnSave: false,
            insertFinalNewlineOnSave: true,
            wrapLines: false,
            showMinimap: false,
            showGutter: true,
            showFoldingRibbon: false,
            currentThemeId: "xcode-light"
        )

        controller.persistConfig(snapshot)
        let restored = controller.restoreConfig()

        XCTAssertEqual(restored.fontSize, 15)
        XCTAssertEqual(restored.tabWidth, 2)
        XCTAssertEqual(restored.useSpaces, false)
        XCTAssertEqual(restored.formatOnSave, true)
        XCTAssertEqual(restored.organizeImportsOnSave, true)
        XCTAssertEqual(restored.currentThemeId, "xcode-light")
    }

    func testResolveConfigAppliesWorkspaceThenLanguageOverrides() {
        let controller = EditorConfigController()
        controller.persistConfig(
            EditorConfigSnapshot(
                fontSize: 13,
                tabWidth: 4,
                useSpaces: true,
                formatOnSave: false,
                organizeImportsOnSave: false,
                fixAllOnSave: false,
                trimTrailingWhitespaceOnSave: true,
                insertFinalNewlineOnSave: true,
                wrapLines: true,
                showMinimap: true,
                showGutter: true,
                showFoldingRibbon: true,
                currentThemeId: "xcode-dark"
            )
        )
        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(
                tabWidth: 2,
                useSpaces: false,
                wrapLines: nil,
                formatOnSave: true
            ),
            for: .workspace("/tmp/demo")
        )
        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(
                tabWidth: 8,
                useSpaces: nil,
                wrapLines: false,
                formatOnSave: nil
            ),
            for: .language("swift")
        )

        let resolved = controller.resolveConfig(
            for: EditorConfigContext(workspacePath: "/tmp/demo", languageId: "swift")
        )

        XCTAssertEqual(resolved.tabWidth, 8)
        XCTAssertEqual(resolved.useSpaces, false)
        XCTAssertEqual(resolved.wrapLines, false)
        XCTAssertEqual(resolved.formatOnSave, true)
    }

    func testPersistOverrideSnapshotRemovesEmptyOverride() {
        let controller = EditorConfigController()
        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(
                tabWidth: 2,
                useSpaces: nil,
                wrapLines: nil,
                formatOnSave: nil
            ),
            for: .language("python")
        )

        XCTAssertEqual(
            controller.overrideSnapshot(
                for: .language("python")
            ).tabWidth,
            2
        )

        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(),
            for: .language("python")
        )

        XCTAssertTrue(
            controller.overrideSnapshot(
                for: .language("python")
            ).isEmpty
        )
    }
}
#endif
