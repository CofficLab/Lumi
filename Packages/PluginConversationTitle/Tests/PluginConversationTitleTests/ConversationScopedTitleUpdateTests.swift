import Foundation
import KitAgentTool
import ProviderConversation
import Testing

@testable import PluginConversationTitle

/// 多会话并发时的标题作用域回归测试。
///
/// ## 要守住的性质
///
/// 一次 `update_conversation_title` 工具调用必须只影响**发起该调用的那个会话**。
/// 工具执行发生在后台（`ToolExecutionRuntime` 用 detached Task 跑），期间用户
/// 完全可能切换当前选中的会话；此时若按「当前选中会话」写标题，就会把 A 的
/// 标题写到 B 上——用户在列表里看到的就是「某个对话的标题突然变成了另一个
/// 对话的标题」。
///
/// `ToolExecutionContext.conversationID` 是宿主在提交工具时冻结下来的会话 ID，
/// 它与 UI 选中态无关，正是这里应该使用的依据。
@Suite("标题更新的会话作用域")
@MainActor
struct ConversationScopedTitleUpdateTests {

    /// 核心回归：工具调用属于会话 A，但执行时 UI 已切到会话 B。
    /// 标题必须写到 A，B 的标题不能被动。
    @Test("标题写入工具调用所属会话而非当前选中会话")
    func writesToCallingConversationInsteadOfSelection() async throws {
        let conversationA = UUID()
        let conversationB = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: conversationA)
        conversations.appendSummary(id: conversationA, title: "A 原标题")
        conversations.appendSummary(id: conversationB, title: "B 原标题")

        let tool = TitleUpdateTool(conversations: conversations)

        // 用户在工具真正执行前切到了会话 B。
        conversations.selected = conversationB

        let context = ToolExecutionContext(
            jobID: "job-for-conversation-a",
            conversationID: conversationA
        )
        let result = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("A 的新标题")]
        )

        #expect(result.content.contains("Conversation Title Updated"))
        #expect(
            conversations.title(of: conversationA) == "A 的新标题",
            "标题必须写入发起本次工具调用的会话 A"
        )
        #expect(
            conversations.title(of: conversationB) == "B 原标题",
            "会话 B 的标题不应被会话 A 的工具调用改写"
        )
    }

    /// 反向同样成立：工具属于 B 时，A 的标题不能被动。
    @Test("会话 B 的工具调用不会污染会话 A 的标题")
    func doesNotLeakIntoOtherConversation() async throws {
        let conversationA = UUID()
        let conversationB = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: conversationA)
        conversations.appendSummary(id: conversationA, title: "A 原标题")
        conversations.appendSummary(id: conversationB, title: "B 原标题")

        let tool = TitleUpdateTool(conversations: conversations)

        let context = ToolExecutionContext(
            jobID: "job-for-conversation-b",
            conversationID: conversationB
        )
        _ = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("B 的新标题")]
        )

        #expect(conversations.title(of: conversationB) == "B 的新标题")
        #expect(conversations.title(of: conversationA) == "A 原标题")
    }

    /// 无 context 的旧调用路径保留「按当前选中会话更新」的行为，
    /// 以免既有集成在拿不到 context 时完全失效。
    @Test("无 context 的旧路径仍按当前选中会话更新")
    func legacyPathStillUsesSelection() async throws {
        let conversationA = UUID()
        let conversationB = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: conversationB)
        conversations.appendSummary(id: conversationA, title: "A 原标题")
        conversations.appendSummary(id: conversationB, title: "B 原标题")

        let tool = TitleUpdateTool(conversations: conversations)

        _ = try await tool.execute(arguments: ["title": ToolArgument("B 的新标题")])

        #expect(conversations.title(of: conversationB) == "B 的新标题")
        #expect(conversations.title(of: conversationA) == "A 原标题")
    }
}
