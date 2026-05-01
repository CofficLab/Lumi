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
        EditorConfigStore.removeValue(forKey: EditorConfigStore.sidePanelWidthKey)
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
            currentThemeId: "xcode-light",
            sidePanelWidth: 420
        )

        controller.persistConfig(snapshot)
        let restored = controller.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })

        XCTAssertEqual(restored.fontSize, 15)
        XCTAssertEqual(restored.tabWidth, 2)
        XCTAssertEqual(restored.useSpaces, false)
        XCTAssertEqual(restored.formatOnSave, true)
        XCTAssertEqual(restored.organizeImportsOnSave, true)
        XCTAssertEqual(restored.currentThemeId, "xcode-light")
        XCTAssertEqual(restored.sidePanelWidth, 420)
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
                currentThemeId: "xcode-dark",
                sidePanelWidth: 360
            )
        )
        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(
                tabWidth: 2,
                useSpaces: false,
                wrapLines: nil,
                formatOnSave: true
            ),
            for: .workspace("/tmp/demo"),
            clampedSidePanelWidth: { CGFloat($0) }
        )
        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(
                tabWidth: 8,
                useSpaces: nil,
                wrapLines: false,
                formatOnSave: nil
            ),
            for: .language("swift"),
            clampedSidePanelWidth: { CGFloat($0) }
        )

        let resolved = controller.resolveConfig(
            for: EditorConfigContext(workspacePath: "/tmp/demo", languageId: "swift"),
            clampedSidePanelWidth: { CGFloat($0) }
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
            for: .language("python"),
            clampedSidePanelWidth: { CGFloat($0) }
        )

        XCTAssertEqual(
            controller.overrideSnapshot(
                for: .language("python"),
                clampedSidePanelWidth: { CGFloat($0) }
            ).tabWidth,
            2
        )

        controller.persistOverrideSnapshot(
            EditorScopedOverrideSnapshot(),
            for: .language("python"),
            clampedSidePanelWidth: { CGFloat($0) }
        )

        XCTAssertTrue(
            controller.overrideSnapshot(
                for: .language("python"),
                clampedSidePanelWidth: { CGFloat($0) }
            ).isEmpty
        )
    }
}
#endif
