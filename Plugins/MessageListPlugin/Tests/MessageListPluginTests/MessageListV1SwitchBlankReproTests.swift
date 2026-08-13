import Foundation
import KernelLumi
import Testing
@testable import MessageListPlugin

/// V1 版本的「切换对话竞态」回归测试。
///
/// 与 V2 的 `MessageListSwitchBlankReproTests` 对应，验证 `ListV1ViewModel`
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
    ) throws -> KernelLumi {
        let kernel = KernelLumi()
        try kernel.registerService(MessageManaging.self, messages)
        try kernel.registerService(ConversationManaging.self, conversations)
        try kernel.registerService(MessageStreaming.self, MockMessageStreaming())
        try kernel.registerService(AgentTurnManaging.self, turnManager)
        return kernel
    }

    /// 断言 viewmodel 的展示消息必须属于指定对话（无外来残留）。
    private func expectConsistent(
        _ viewModel: ListV1ViewModel,
        selectedID: UUID?,
        sourceComment: String
    ) {
        if let selectedID {
            let foreign = viewModel.displayMessages.filter { $0.conversationID != selectedID }
            if !foreign.isEmpty {
                Issue.record(
                    "\(sourceComment): displayMessages 残留了非当前对话的消息(数据错配 → 可能空白)。外来消息数=\(foreign.count)"
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

    @Test("长对话切短对话:激活后展示消息必须属于短对话,无外来残留")
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
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)

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

    @Test("快速来回切:最终激活的对话必须是展示消息的归属对话")
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
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)

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

    @Test("isLoading 翻false后,hasVisibleContent 与 items 必须一致")
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
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)

        conversations.selectedConversationID = longID
        await viewModel.activate(conversationID: longID)
        conversations.selectedConversationID = shortID
        await viewModel.activate(conversationID: shortID)

        // 加载完成后状态一致性检查
        #expect(viewModel.isLoading == false)
        #expect(viewModel.hasVisibleContent == !viewModel.items.isEmpty)
        expectConsistent(viewModel, selectedID: shortID, sourceComment: "加载完成后")
    }

    @Test("只有当前最新的运行中 Turn 接收实时活动")
    func onlyLatestRunningTurnAcceptsLiveActivity() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let streaming = MockMessageStreaming()
        let conversationID = UUID()
        let olderTurnID = UUID()
        let activeTurnID = UUID()
        let base = Date(timeIntervalSinceReferenceDate: 1_000)

        turnManager.seed([
            AgentTurnRecord(
                id: olderTurnID,
                conversationID: conversationID,
                state: .running,
                startedAt: base
            ),
            AgentTurnRecord(
                id: activeTurnID,
                conversationID: conversationID,
                state: .running,
                startedAt: base.addingTimeInterval(10)
            ),
        ], conversationID: conversationID)

        let kernel = KernelLumi()
        try kernel.registerService(MessageManaging.self, messages)
        try kernel.registerService(ConversationManaging.self, conversations)
        try kernel.registerService(MessageStreaming.self, streaming)
        try kernel.registerService(AgentTurnManaging.self, turnManager)
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)

        conversations.selectedConversationID = conversationID
        await viewModel.activate(conversationID: conversationID)
        let older = try #require(viewModel.agentTurns.first { $0.id == olderTurnID })
        let active = try #require(viewModel.agentTurns.first { $0.id == activeTurnID })
        #expect(older.acceptsLiveActivity == false)
        #expect(active.acceptsLiveActivity == true)
    }

    @Test("用户消息先落库时立即展示,Turn 出现后无重复")
    func userMessageAppearsBeforeTurnAndMergesAfterTurnCreation() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let conversationID = UUID()
        let userMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "立即显示我",
            createdAt: Date(timeIntervalSinceReferenceDate: 2_000)
        )

        messages.seed([userMessage], conversationID: conversationID)
        let kernel = try makeKernel(
            messages: messages,
            conversations: conversations,
            turnManager: turnManager
        )
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)
        conversations.selectedConversationID = conversationID

        await viewModel.activate(conversationID: conversationID)

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.pendingUserMessages.map(\.id) == [userMessage.id])
        #expect(viewModel.hasVisibleContent == true)

        let turnID = UUID()
        turnManager.seed([
            AgentTurnRecord(
                id: turnID,
                conversationID: conversationID,
                state: .running,
                startedAt: userMessage.createdAt.addingTimeInterval(0.1)
            ),
        ], conversationID: conversationID)
        _ = await viewModel.refresh()

        #expect(viewModel.pendingUserMessages.isEmpty)
        #expect(viewModel.items.first?.userMessage?.id == userMessage.id)
    }

    @Test("分页窗口之外的旧用户消息不会被误判为待处理尾行")
    func olderUnclaimedUserMessageIsNotPending() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let conversationID = UUID()
        let oldUser = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "旧分页消息",
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )
        let latestUser = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "当前消息",
            createdAt: Date(timeIntervalSinceReferenceDate: 2_000)
        )
        let latestTurnID = UUID()
        turnManager.seed([
            AgentTurnRecord(
                id: latestTurnID,
                conversationID: conversationID,
                state: .running,
                startedAt: Date(timeIntervalSinceReferenceDate: 2_001)
            ),
        ], conversationID: conversationID)
        messages.seed([oldUser, latestUser], conversationID: conversationID)

        let kernel = try makeKernel(
            messages: messages,
            conversations: conversations,
            turnManager: turnManager
        )
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 1)
        conversations.selectedConversationID = conversationID
        await viewModel.activate(conversationID: conversationID)

        #expect(viewModel.items.first?.userMessage?.id == latestUser.id)
        #expect(viewModel.pendingUserMessages.isEmpty)
    }

    @Test("空状态也会响应第一条用户消息通知")
    func emptyStateRefreshesWhenFirstUserMessageArrives() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let conversationID = UUID()
        let kernel = try makeKernel(
            messages: messages,
            conversations: conversations,
            turnManager: turnManager
        )
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)
        conversations.selectedConversationID = conversationID
        await viewModel.activate(conversationID: conversationID)
        #expect(viewModel.hasVisibleContent == false)

        let userMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "第一条消息"
        )
        messages.seed([userMessage], conversationID: conversationID)
        NotificationCenter.default.post(
            name: .lumiMessagesDidChange,
            object: nil,
            userInfo: [LumiNotificationUserInfoKey.conversationID: conversationID]
        )
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(viewModel.pendingUserMessages.map(\.id) == [userMessage.id])
        #expect(viewModel.hasVisibleContent == true)
    }

    @Test("Turn 建立前立即展示最新 Status,建立后归入动态 Turn")
    func statusAppearsBeforeTurnAndMovesIntoActiveTurn() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let conversationID = UUID()
        let userMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "开始工作",
            createdAt: Date(timeIntervalSinceReferenceDate: 3_000)
        )
        let status = LumiChatMessage(
            conversationID: conversationID,
            role: .status,
            content: "正在发送消息…",
            createdAt: Date(timeIntervalSinceReferenceDate: 3_001),
            metadata: ["isTransientStatus": "true"]
        )
        messages.seed([userMessage, status], conversationID: conversationID)

        let kernel = try makeKernel(
            messages: messages,
            conversations: conversations,
            turnManager: turnManager
        )
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)
        conversations.selectedConversationID = conversationID
        await viewModel.activate(conversationID: conversationID)

        #expect(viewModel.pendingUserMessages.map(\.id) == [userMessage.id])
        #expect(viewModel.pendingStatusMessage?.id == status.id)
        #expect(viewModel.hasVisibleContent == true)

        let turnID = UUID()
        turnManager.seed([
            AgentTurnRecord(
                id: turnID,
                conversationID: conversationID,
                state: .running,
                startedAt: userMessage.createdAt.addingTimeInterval(0.5)
            ),
        ], conversationID: conversationID)
        _ = await viewModel.refresh()

        #expect(viewModel.pendingStatusMessage == nil)
        #expect(viewModel.items.first?.processMessages.map(\.id) == [status.id])
    }

    @Test("V1 列表统一输出 AgentTurn 展示项")
    func listProjectsPendingAndRecordedAgentTurns() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let turnManager = MockAgentTurnManager()
        let conversationID = UUID()
        let userMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "保持同一个 Turn View",
            createdAt: Date(timeIntervalSinceReferenceDate: 4_000)
        )
        messages.seed([userMessage], conversationID: conversationID)
        let kernel = try makeKernel(
            messages: messages,
            conversations: conversations,
            turnManager: turnManager
        )
        let viewModel = ListV1ViewModel(kernel: kernel, pageSize: 40)
        conversations.selectedConversationID = conversationID
        await viewModel.activate(conversationID: conversationID)

        #expect(viewModel.agentTurns.count == 1)
        #expect(viewModel.agentTurns.first?.isPending == true)
        #expect(viewModel.agentTurns.first?.id == userMessage.id)

        let turnID = UUID()
        turnManager.seed([
            AgentTurnRecord(
                id: turnID,
                conversationID: conversationID,
                state: .running,
                startedAt: userMessage.createdAt.addingTimeInterval(0.1)
            ),
        ], conversationID: conversationID)
        _ = await viewModel.refresh()

        #expect(viewModel.agentTurns.count == 1)
        #expect(viewModel.agentTurns.first?.isPending == false)
        #expect(viewModel.agentTurns.first?.id == turnID)
        #expect(viewModel.agentTurns.first?.conversationID == conversationID)
        #expect(viewModel.agentTurns.first?.record?.id == turnID)
    }
}
