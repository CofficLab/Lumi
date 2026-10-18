import Foundation
import KernelCore
import ProviderConversation
import ProviderMessage
import Testing

@testable import PluginConversationTitle

/// `TitleService` 的端到端链路测试：消息插入事件 → 标题决策 → 写库。
///
/// 这批用例锁定的是自动标题的**行为边界**，尤其是三条「不写库」路径：
/// 非首条用户消息、用户已有自定义标题、LLM 失败。三者任一被误改，
/// 都会造成标题被意外覆盖或请求额度浪费。
@Suite("自动标题链路")
@MainActor
struct TitleServiceTests {

    // MARK: - Helpers

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

    private func userMessage(
        _ content: String,
        in conversationID: UUID,
        role: MessageRole = .user
    ) -> Message {
        Message(conversationID: conversationID, role: role, content: content)
    }

    /// 事件回调内部是 `Task { @MainActor }`，需要让出执行权等它跑完。
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    // MARK: - Happy path

    /// 首条用户消息应触发一次 LLM 请求，并把清洗后的标题写入会话。
    @Test("首条用户消息生成标题并写库")
    func generatesTitleForFirstUserMessage() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "  “自动标题”  ")

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("帮我写个排序算法", in: conversationID))
        await settle()

        #expect(llm.receivedRequests.count == 1)
        // 引号被剥离后才落库
        #expect(conversations.title(of: conversationID) == "自动标题")
    }

    /// 请求组装：system prompt + 被 `<first_message>` 包裹的用户消息。
    @Test("生成标题的请求包含 system 指令与包裹后的用户消息")
    func composesPromptWithFence() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "标题")

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("原始问题", in: conversationID))
        await settle()

        let request = try! #require(llm.receivedRequests.first)
        #expect(request.conversationID == conversationID)
        #expect(request.messages.count == 2)
        let system = try! #require(request.messages.first)
        let user = try! #require(request.messages.last)
        #expect(system.content.contains("conversation-title generator"))
        #expect(user.content.contains("<first_message>"))
        #expect(user.content.contains("原始问题"))
    }

    // MARK: - 三条「不写库」路径

    /// 第二条及后续用户消息不重新生成标题。
    @Test("非首条用户消息不触发标题生成")
    func ignoresNonFirstUserMessage() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let first = userMessage("第一条", in: conversationID)
        let messages = TitleTestDoubles.StubMessageManager(messages: [first])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("第二条", in: conversationID))
        await settle()

        #expect(llm.receivedRequests.isEmpty)
        #expect(conversations.titleUpdateRequests.isEmpty)
    }

    /// 非用户角色（assistant / system 等）直接忽略，不查首条消息。
    @Test("非用户角色的消息被忽略")
    func ignoresNonUserRole() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("助手消息", in: conversationID, role: .assistant))
        await settle()

        #expect(llm.receivedRequests.isEmpty)
        #expect(conversations.titleUpdateRequests.isEmpty)
    }

    /// 用户手动改过标题后，LLM 结果不得覆盖。
    @Test("已有自定义标题时不覆盖")
    func doesNotOverwriteCustomTitle() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: "我手动写的标题")
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "LLM 标题")

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("首个问题", in: conversationID))
        await settle()

        #expect(llm.receivedRequests.isEmpty)
        #expect(conversations.titleUpdateRequests.isEmpty)
        #expect(conversations.title(of: conversationID) == "我手动写的标题")
    }

    /// LLM 抛错时不得写入任何标题，会话应保持原状。
    @Test("LLM 失败时不写库")
    func doesNotPersistWhenLLMFails() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(
            completionError: StubLLMError(reason: "network down")
        )

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("首个问题", in: conversationID))
        await settle()

        #expect(llm.receivedRequests.count == 1)
        #expect(conversations.titleUpdateRequests.isEmpty)
        #expect(conversations.title(of: conversationID) == nil)
    }

    /// LLM 返回空标题时视为无结果，不写库。
    @Test("LLM 返回空标题时不写库")
    func doesNotPersistEmptyTitle() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        // 只有空白与引号，清洗后为空串
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "   “”  \n  ")

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("首个问题", in: conversationID))
        await settle()

        #expect(conversations.titleUpdateRequests.isEmpty)
        #expect(conversations.title(of: conversationID) == nil)
    }

    /// 写库失败（Provider 返回 false）不应崩溃，也不能污染内存态。
    @Test("写库失败时不抛出异常")
    func toleratesPersistenceFailure() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        conversations.failTitleUpdate = true
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "标题")

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("首个问题", in: conversationID))
        await settle()

        #expect(conversations.titleUpdateRequests.count == 1)
        #expect(conversations.title(of: conversationID) == nil)
    }

    /// 内容为空的用户消息不应触发任何 LLM 请求。
    @Test("空内容用户消息被忽略")
    func ignoresBlankMessage() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("   \n  ", in: conversationID))
        await settle()

        #expect(llm.receivedRequests.isEmpty)
        #expect(conversations.titleUpdateRequests.isEmpty)
    }

    // MARK: - 生命周期

    /// `stop()` 应释放消息订阅，之后再 emit 不应有任何反应。
    @Test("stop 后不再响应消息插入")
    func stopsObserving() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        #expect(messages.isObserving)

        service.stop()
        #expect(!messages.isObserving)

        messages.emitInserted(userMessage("首个问题", in: conversationID))
        await settle()

        #expect(llm.receivedRequests.isEmpty)
        #expect(conversations.titleUpdateRequests.isEmpty)
    }

    /// 重复调用 `stop()` 不应崩溃，也不应重复计数。
    @Test("重复 stop 幂等")
    func stopIsIdempotent() async {
        let messages = TitleTestDoubles.StubMessageManager()
        let service = makeService(
            messages: messages,
            conversations: TitleTestDoubles.StubConversationManager(),
            llm: TitleTestDoubles.StubLLMManager()
        )

        service.stop()
        service.stop()

        #expect(messages.insertHandle.cancelCount == 1)
    }
}
