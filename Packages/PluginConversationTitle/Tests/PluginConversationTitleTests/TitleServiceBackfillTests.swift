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

    /// 回归 #799：永久跳过的条目填满查询窗口时，窗口之外的有效对话仍须被回填。
    ///
    /// 旧实现只取前 200 条无标题 ID。`S1...S200` 都没有首条用户消息，每轮都被
    /// 跳过却不写标题、不推进游标，于是查询窗口永远被它们占满，排在窗口之外的
    /// `V`（有首条用户消息）在任何一次启动都轮不到，永远停在占位符。
    @Test("永久跳过的条目不得阻塞窗口之外的有效对话")
    func skippedWindowDoesNotBlockValidConversation() async {
        let conversations = TitleTestDoubles.StubConversationManager()
        // 200 条无标题、无首条用户消息的对话：每轮都会被永久跳过。
        var skippedIDs: [UUID] = []
        for _ in 0..<200 {
            let id = UUID()
            skippedIDs.append(id)
            conversations.appendSummary(id: id, title: nil)
        }
        // 排在窗口之外的有效对话。
        let validID = UUID()
        conversations.appendSummary(id: validID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager(messages: [
            Message(conversationID: validID, role: .user, content: "Investigate login timeout")
        ])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(messages: messages, conversations: conversations, llm: llm)
        defer { service.stop() }

        let backfilled = await service.backfillUntitledConversations()

        #expect(backfilled == 1, "窗口之外的有效对话必须被回填")
        #expect(conversations.title(of: validID) == "Investigate login timeout")
        #expect(llm.receivedRequests.isEmpty, "回填不应消耗 LLM 额度")
        for id in skippedIDs {
            #expect(conversations.title(of: id) == nil, "无首条用户消息的对话不应被写入空标题")
        }

        // 再跑一轮：V 已有标题，不应重复补写；跳过条目仍不阻塞。
        let secondRun = await service.backfillUntitledConversations()
        #expect(secondRun == 0)
        #expect(conversations.title(of: validID) == "Investigate login timeout")
    }

    /// 上限仍约束成功补写的条数：一次启动最多补 200 条，剩下的留到下次启动。
    @Test("单轮回填遵守补写上限")
    func backfillStopsAtWriteCap() async {
        let conversations = TitleTestDoubles.StubConversationManager()
        var messages: [Message] = []
        var ids: [UUID] = []
        for index in 0..<201 {
            let id = UUID()
            ids.append(id)
            conversations.appendSummary(id: id, title: nil)
            messages.append(Message(conversationID: id, role: .user, content: "问题 \(index)"))
        }
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: TitleTestDoubles.StubMessageManager(messages: messages),
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        let backfilled = await service.backfillUntitledConversations()

        #expect(backfilled == 200, "单轮最多补写 200 条，实际 \(backfilled)")
        let untitledCount = ids.filter { conversations.title(of: $0) == nil }.count
        #expect(untitledCount == 1, "应恰好剩 1 条留到下次启动，实际 \(untitledCount)")
    }
}
