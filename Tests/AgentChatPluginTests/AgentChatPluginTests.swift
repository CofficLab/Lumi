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
        XCTAssertEqual(ModelSelectorTab.current.displayTitle, "Current Provider")
        XCTAssertEqual(ModelSelectorTab.frequent.displayTitle, "Frequent")
        XCTAssertEqual(ModelSelectorTab.fast.displayTitle, "Fast")
        XCTAssertEqual(ModelSelectorTab.all.displayTitle, "All")
        XCTAssertEqual(ModelSelectorTab.provider("openai").displayTitle, "")
    }
}
#endif
