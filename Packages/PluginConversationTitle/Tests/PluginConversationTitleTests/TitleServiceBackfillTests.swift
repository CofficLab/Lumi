import Foundation
import KernelCore
import ProviderConversation
import ProviderMessage
import Testing

@testable import PluginConversationTitle

/// 验证**存量无标题对话的回填**。
///
/// ## 为什么需要回填
///
/// 自动标题只对「首条用户消息」生效。标题生成失败过一次，对话就**永久**停在
/// 无标题状态：修好鉴权或额度之后，也没有新的首条用户消息来触发重试。
///
/// 这些对话在列表里只能显示通用占位符，看起来就是一条空条目——哪怕它有
/// 几百条消息。回填用首条用户消息作为占位标题，让用户能在列表里认出它们。
///
/// ## 不变量
///
/// - 回填只为**没有标题**的对话补写，已有标题（包括用户手动改过的）不动。
/// - 回填**不调用 LLM**：历史对话可能成百上千条，逐条请求既慢又可能再次失败
///   ——鉴权或额度问题正是它们变成无标题的原因。
/// - 没有首条用户消息的对话无从取材，跳过而不是写入空标题。
@Suite("无标题对话的回填")
@MainActor
struct TitleServiceBackfillTests {

    private func makeService(
        messages: TitleTestDoubles.StubMessageManager,
        conversations: TitleTestDoubles.StubConversationManager,
        llm: TitleTestDoubles.StubLLMManager
    ) -> TitleService {
        TitleService(
            kernel: KernelCoreContainer(),
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
    }

    @Test("回填为无标题对话补写占位标题")
    func backfillsUntitledConversation() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager(messages: [
            Message(conversationID: conversationID, role: .user, content: "帮我排查登录超时的问题")
        ])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        let backfilled = await service.backfillUntitledConversations()

        #expect(backfilled == 1)
        #expect(conversations.title(of: conversationID) == "帮我排查登录超时的问题")
        #expect(llm.receivedRequests.isEmpty, "回填不应消耗 LLM 额度")
    }

    @Test("回填跳过已有标题的对话")
    func skipsTitledConversation() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: "用户自己写的标题")
        let messages = TitleTestDoubles.StubMessageManager(messages: [
            Message(conversationID: conversationID, role: .user, content: "首个问题")
        ])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        let backfilled = await service.backfillUntitledConversations()

        #expect(backfilled == 0)
        #expect(conversations.title(of: conversationID) == "用户自己写的标题")
    }

    @Test("回填跳过没有首条用户消息的对话")
    func skipsConversationWithoutUserMessage() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        // 只有助手消息：无从取材，不能写入空标题。
        let messages = TitleTestDoubles.StubMessageManager(messages: [
            Message(conversationID: conversationID, role: .assistant, content: "助手消息")
        ])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        let backfilled = await service.backfillUntitledConversations()

        #expect(backfilled == 0)
        #expect(conversations.title(of: conversationID) == nil)
    }

    @Test("回填把过长的首条消息截断")
    func truncatesLongFirstUserMessage() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let long = String(repeating: "需求描述 ", count: 20)
        let messages = TitleTestDoubles.StubMessageManager(messages: [
            Message(conversationID: conversationID, role: .user, content: long)
        ])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        await service.backfillUntitledConversations()

        let title = conversations.title(of: conversationID) ?? ""
        #expect(!title.isEmpty)
        #expect(title.count <= 41, "占位标题过长：\(title.count) 字")
    }
}
