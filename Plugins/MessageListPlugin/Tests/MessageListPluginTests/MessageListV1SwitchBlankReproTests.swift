import Foundation
import LumiKernel
import Testing
@testable import MessageListPlugin

/// V1 版本的「切换对话竞态」回归测试。
///
/// 与 V2 的 `MessageListSwitchBlankReproTests` 对应，验证 `MessageListV1ViewModel`
/// 在并发切换对话时，`records` 和 `presentation` 必须属于用户最终选中的对话。
///
/// 根因：`activate` 使用 `activeConversationID`（可变共享状态）做过期守卫，
/// 并发调用时会被最后一个子任务覆盖，导致先完成的结果被错误丢弃。
@Suite("V1 切换对话竞态回归 (ViewModel 层)", .serialized)
@MainActor
struct MessageListV1SwitchBlankReproTests {

    // MARK: - Helpers

    private func makeKernel(
        messages: MockMessageManager,
        conversations: MockConversationManager,
        turnManager: MockAgentTurnManager
    ) throws -> LumiKernel {
        let kernel = LumiKernel()
        try kernel.registerService(MessageManaging.self, messages)
        try kernel.registerService(ConversationManaging.self, conversations)
        try kernel.registerService(MessageStreaming.self, MockMessageStreaming())
        try kernel.registerService(AgentTurnManaging.self, turnManager)
        return kernel
    }

    /// 断言 viewmodel 的结论消息必须属于指定对话（无外来残留）。
    private func expectConsistent(
        _ viewModel: MessageListV1ViewModel,
        selectedID: UUID?,
        sourceComment: String
    ) {
        if let selectedID {
            let foreign = viewModel.conclusionMessages.filter { $0.conversationID != selectedID }
            if !foreign.isEmpty {
                Issue.record(
                    "\(sourceComment): conclusionMessages 残留了非当前对话的消息(数据错配 → 可能空白)。外来消息数=\(foreign.count)"
                )
            }
            #expect(foreign.isEmpty)
        }
    }

    /// 创建 turn 记录和对应的消息（消息的 turnID 匹配记录 id）。
    private func makeTurnsWithMessages(
        count: Int,
        conversationID: UUID,
        baseTime: TimeInterval = 1_000
    ) -> (records: [AgentTurnRecord], messages: [LumiChatMessage]) {
        var records: [AgentTurnRecord] = []
        var messages: [LumiChatMessage] = []
        for i in 0..<count {
            let turnID = UUID()
            let startTime = baseTime + Double(i) * 10
            // 每个 turn: user message + assistant response
            records.append(AgentTurnRecord(
                id: turnID,
                conversationID: conversationID,
                state: .completed,
                startedAt: Date(timeIntervalSinceReferenceDate: startTime),
                endedAt: Date(timeIntervalSinceReferenceDate: startTime + 2)
            ))
            messages.append(LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .user,
                content: "user message \(i)",
                turnID: turnID,
                createdAt: Date(timeIntervalSinceReferenceDate: startTime)
            ))
            messages.append(LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .assistant,
                content: "assistant response \(i) — some content to render",
                turnID: turnID,
                createdAt: Date(timeIntervalSinceReferenceDate: startTime + 1)
            ))
        }
        return (records, messages)
    }

    // MARK: - Tests

    @Test("长对话切短对话:激活后 conclusionMessages 必须属于短对话,无外来残留")
    func longToShort_noForeignRowsAfterSwitch() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let longID = UUID()
        let shortID = UUID()

        // 长对话有 50 个 turns，短对话只有 3 个
        let longData = makeTurnsWithMessages(count: 50, conversationID: longID)
        let shortData = makeTurnsWithMessages(count: 3, conversationID: shortID)

        turnManager.seed(longData.records, conversationID: longID)
        turnManager.seed(shortData.records, conversationID: shortID)
        messages.seed(longData.messages, conversationID: longID)
        messages.seed(shortData.messages, conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations, turnManager: turnManager)
        let viewModel = MessageListV1ViewModel(kernel: kernel, pageSize: 40)

        // 1. 先进入长对话并等其加载完
        conversations.selectedConversationID = longID
        await viewModel.activate(conversationID: longID)
        #expect(viewModel.items.count == 40, "长对话首屏应为 pageSize=40 条")

        // 2. 切到短对话
        conversations.selectedConversationID = shortID
        await viewModel.activate(conversationID: shortID)

        // 3. 激活完成后:必须是短对话的 3 条,不能残留长对话消息
        #expect(viewModel.items.count == 3, "短对话应有 3 条,实际 \(viewModel.items.count)")
        expectConsistent(viewModel, selectedID: shortID, sourceComment: "长切短后")
    }

    @Test("快速来回切:最终激活的对话必须是 conclusionMessages 的归属对话")
    func rapidSwitch_finalStateConsistent() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let longID = UUID()
        let shortID = UUID()

        let longData = makeTurnsWithMessages(count: 50, conversationID: longID)
        let shortData = makeTurnsWithMessages(count: 3, conversationID: shortID)

        turnManager.seed(longData.records, conversationID: longID)
        turnManager.seed(shortData.records, conversationID: shortID)
        messages.seed(longData.messages, conversationID: longID)
        messages.seed(shortData.messages, conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations, turnManager: turnManager)
        let viewModel = MessageListV1ViewModel(kernel: kernel, pageSize: 40)

        // 顺序切换三次，确保最终状态正确
        // 注意：由于 @MainActor 方法会序列化执行，真正的并发竞态需要异步延迟来触发
        conversations.selectedConversationID = longID
        let taskA = Task { await viewModel.activate(conversationID: longID) }
        await Task.yield()

        conversations.selectedConversationID = shortID
        let taskB = Task { await viewModel.activate(conversationID: shortID) }
        await Task.yield()

        conversations.selectedConversationID = longID
        let taskC = Task { await viewModel.activate(conversationID: longID) }

        _ = await (taskA.value, taskB.value, taskC.value)

        // 最终选中的是 longID，viewmodel 必须收敛到 longID 且内容属于 longID
        #expect(viewModel.items.count == 40, "最终应收敛到长对话 40 条,实际 \(viewModel.items.count)")
        expectConsistent(viewModel, selectedID: longID, sourceComment: "快速来回切后")
    }

    @Test("isLoading 翻false后,hasVisibleContent 与 conclusionMessages 必须一致")
    func afterLoading_consistentVisibleState() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let longID = UUID()
        let shortID = UUID()

        let longData = makeTurnsWithMessages(count: 50, conversationID: longID)
        let shortData = makeTurnsWithMessages(count: 4, conversationID: shortID)

        turnManager.seed(longData.records, conversationID: longID)
        turnManager.seed(shortData.records, conversationID: shortID)
        messages.seed(longData.messages, conversationID: longID)
        messages.seed(shortData.messages, conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations, turnManager: turnManager)
        let viewModel = MessageListV1ViewModel(kernel: kernel, pageSize: 40)

        conversations.selectedConversationID = longID
        await viewModel.activate(conversationID: longID)
        conversations.selectedConversationID = shortID
        await viewModel.activate(conversationID: shortID)

        // 加载完成后状态一致性检查
        #expect(viewModel.isLoading == false)
        #expect(viewModel.hasVisibleContent == !viewModel.conclusionMessages.isEmpty)
        expectConsistent(viewModel, selectedID: shortID, sourceComment: "加载完成后")
    }
}
