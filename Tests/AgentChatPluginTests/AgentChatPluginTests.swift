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

    func testAutoTaskSidebarSectionsAreAvailableForChatPanelIcon() async {
        let sections = await AutoTaskPlugin.shared.addSidebarSections(activeIcon: ChatPanelPlugin.iconName)
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

    func testLayoutMenuIsAvailableForChatPanel() async {
        XCTAssertNotNil(await LayoutPlugin.shared.addToolBarTrailingView(activeIcon: EditorPlugin.iconName))
        XCTAssertNotNil(await LayoutPlugin.shared.addToolBarTrailingView(activeIcon: ChatPanelPlugin.iconName))
        XCTAssertNil(await LayoutPlugin.shared.addToolBarTrailingView(activeIcon: "not-supported"))
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

    func testAutoConversationTitleAllowsEmptyStoredTitle() {
        let result = AutoConversationTitlePolicy().evaluate(
            AutoConversationTitlePolicy.Input(
                role: .user,
                userText: "帮我分析一下这个项目结构",
                currentTitle: "",
                userMessageCount: 1,
                newConversationTitle: "New Conversation",
                newChatTitlePrefix: "New Chat"
            )
        )

        XCTAssertTrue(result.shouldGenerate)
        XCTAssertEqual(result.trimmedUserText, "帮我分析一下这个项目结构")
    }

    func testAutoConversationTitleAllowsLegacyChineseDefaultConversationTitle() {
        let result = AutoConversationTitlePolicy().evaluate(
            AutoConversationTitlePolicy.Input(
                role: .user,
                userText: "帮我分析一下这个项目结构",
                currentTitle: "新对话",
                userMessageCount: 1,
                newConversationTitle: "New Conversation",
                newChatTitlePrefix: "New Chat"
            )
        )

        XCTAssertTrue(result.shouldGenerate)
    }

    func testAutoConversationTitleSkipsNonDefaultTitle() {
        let result = AutoConversationTitlePolicy().evaluate(
            AutoConversationTitlePolicy.Input(
                role: .user,
                userText: "继续",
                currentTitle: "已有标题",
                userMessageCount: 1,
                newConversationTitle: "New Conversation",
                newChatTitlePrefix: "New Chat"
            )
        )

        XCTAssertFalse(result.shouldGenerate)
        XCTAssertNil(result.trimmedUserText)
    }
}
#endif
