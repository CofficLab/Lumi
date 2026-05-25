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

    func testSidebarSectionsAreEmptyForNonEditorIcon() async {
        let sections = await AgentChatPlugin.shared.addSidebarSections(activeIcon: "not-editor")
        XCTAssertTrue(sections.isEmpty)
    }

    func testSidebarSectionsAreAvailableForEditorIcon() async {
        let sections = await AgentChatPlugin.shared.addSidebarSections(activeIcon: EditorPlugin.iconName)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.count, 1)
    }

    func testSidebarSectionsAreAvailableForChatPanelIcon() async {
        let sections = await AgentChatPlugin.shared.addSidebarSections(activeIcon: ChatPanelPlugin.iconName)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.count, 1)
    }

    func testChatPanelPluginProvidesNavigationEntry() async {
        XCTAssertEqual(ChatPanelPlugin.id, "ChatPanel")
        XCTAssertEqual(ChatPanelPlugin.iconName, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(ChatPanelPlugin.shared.addPanelIcon(), ChatPanelPlugin.iconName)
        XCTAssertNotNil(await ChatPanelPlugin.shared.addPanelView(activeIcon: ChatPanelPlugin.iconName))
        XCTAssertNil(await ChatPanelPlugin.shared.addPanelView(activeIcon: EditorPlugin.iconName))
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
