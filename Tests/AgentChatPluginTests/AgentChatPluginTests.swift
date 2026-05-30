#if canImport(XCTest)
import XCTest
import LumiCoreKit
@testable import PluginAutoTask
@testable import PluginChatMessages
@testable import PluginChatPanel
@testable import PluginConversationTitle
@testable import PluginEditorPanel
@testable import PluginLayout
@testable import PluginModelSelector
@testable import Lumi

@MainActor
final class AgentChatPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(AgentChatPlugin.id, "AgentChat")
        XCTAssertEqual(AgentChatPlugin.iconName, "text.bubble.fill")
        XCTAssertTrue(AgentChatPlugin.enable)
        XCTAssertEqual(AgentChatPlugin.order, 82)
    }

    func testSidebarSectionsAreEmptyForNonAIChatIcon() async {
        let context = PluginContext(activeIcon: "not-editor")
        let sections = await AgentChatPlugin.shared.addSidebarSections(context: context)
        XCTAssertTrue(sections.isEmpty)
    }

    func testSidebarSectionsAreAvailableForEditorIcon() async {
        let context = PluginContext(activeIcon: EditorPlugin.iconName, supportsAIChat: true)
        let sections = await AgentChatPlugin.shared.addSidebarSections(context: context)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.count, 1)
    }

    func testSidebarSectionsAreAvailableForChatPanelIcon() async {
        let context = PluginContext(activeIcon: ChatPanelPlugin.iconName, supportsAIChat: true)
        let sections = await AgentChatPlugin.shared.addSidebarSections(context: context)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.count, 1)
    }

    func testAutoTaskSidebarSectionsAreAvailableForChatPanelIcon() async {
        let context = PluginContext(activeIcon: ChatPanelPlugin.iconName, supportsAIChat: true)
        let sections = await AutoTaskPlugin.shared.addSidebarSections(context: context)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.count, 1)
    }

    func testChatPanelPluginProvidesNavigationEntry() async {
        XCTAssertEqual(ChatPanelPlugin.id, "ChatPanel")
        XCTAssertEqual(ChatPanelPlugin.iconName, "bubble.left.and.bubble.right.fill")
        let item = await ChatPanelPlugin.shared.addViewContainer()
        XCTAssertEqual(item?.id, ChatPanelPlugin.id)
        XCTAssertEqual(item?.title, ChatPanelPlugin.displayName)
        XCTAssertEqual(item?.icon, ChatPanelPlugin.iconName)
    }

    func testLayoutMenuIsAvailableForChatPanel() async {
        let editorContext = PluginContext(activeIcon: EditorPlugin.iconName)
        let editorToolbarView = await LayoutPlugin.shared.addToolBarTrailingView(context: editorContext)
        XCTAssertNotNil(editorToolbarView)

        let chatContext = PluginContext(activeIcon: ChatPanelPlugin.iconName)
        let chatToolbarView = await LayoutPlugin.shared.addToolBarTrailingView(context: chatContext)
        XCTAssertNotNil(chatToolbarView)

        let otherContext = PluginContext(activeIcon: "not-supported")
        let unsupportedToolbarView = await LayoutPlugin.shared.addToolBarTrailingView(context: otherContext)
        XCTAssertNil(unsupportedToolbarView)
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
