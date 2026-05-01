#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorSettingsQuickOpenControllerTests: XCTestCase {
    override func tearDown() {
        AppSettingStore.clearSettingsSelection()
        AppSettingStore.savePendingEditorSettingsSearchQuery(nil)
        super.tearDown()
    }

    func testSuggestionsIncludeMatchingBuiltInSettings() {
        let controller = EditorSettingsQuickOpenController()

        let items = controller.suggestions(matching: "minimap")

        XCTAssertTrue(items.contains(where: { $0.title == "Minimap" }))
    }

    func testSuggestionActionStoresSettingsDeepLink() {
        let controller = EditorSettingsQuickOpenController()
        let item = try XCTUnwrap(controller.suggestions(matching: "wrap").first(where: { $0.title == "Word Wrap" }))

        item.action()

        let selection = AppSettingStore.loadSettingsSelection()
        XCTAssertEqual(selection?.type, "core")
        XCTAssertEqual(selection?.value, SettingTab.editor.rawValue)
        XCTAssertEqual(AppSettingStore.loadPendingEditorSettingsSearchQuery(), "wrap")
    }
}
#endif
