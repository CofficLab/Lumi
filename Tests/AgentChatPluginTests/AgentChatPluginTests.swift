#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class AgentChatPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(AgentChatPlugin.id, "AgentChat")
        XCTAssertEqual(AgentChatPlugin.iconName, "text.bubble.fill")
        XCTAssertTrue(AgentChatPlugin.enable)
        XCTAssertEqual(AgentChatPlugin.order, 82)
    }

    func testSidebarViewIsHiddenForNonEditorIcon() async {
        let view = await AgentChatPlugin.shared.addSidebarView(activeIcon: "not-editor")
        XCTAssertNil(view)
    }

    func testSidebarViewIsAvailableForEditorIcon() async {
        let view = await AgentChatPlugin.shared.addSidebarView(activeIcon: EditorPlugin.iconName)
        XCTAssertNotNil(view)
    }

    func testModelSelectorTabBuiltInTitlesRemainStable() {
        XCTAssertEqual(
            ModelSelectorTab.current.displayTitle,
            String(localized: "Current Provider", table: "AgentChat")
        )
        XCTAssertEqual(
            ModelSelectorTab.frequent.displayTitle,
            String(localized: "Frequent", table: "AgentChat")
        )
        XCTAssertEqual(
            ModelSelectorTab.fast.displayTitle,
            String(localized: "Fast", table: "AgentChat")
        )
        XCTAssertEqual(
            ModelSelectorTab.all.displayTitle,
            String(localized: "All", table: "AgentChat")
        )
        XCTAssertEqual(ModelSelectorTab.provider("openai").displayTitle, "")
    }
}
#endif
