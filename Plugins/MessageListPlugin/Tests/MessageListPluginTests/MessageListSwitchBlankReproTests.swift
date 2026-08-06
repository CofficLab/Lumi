import Foundation
import LumiKernel
import Testing
@testable import MessageListPlugin

/// 「长对话切短对话 → 列表空白」的数据层回归测试。
///
/// 线上现象: macOS 14 上,从一个消息很多的对话切到消息很少的对话时,
/// 整个消息列表偶发渲染成空白,手动滚动一下才恢复。
///
/// 数据层根因假设: 切换对话时,`activate` 先把旧对话的 `historyRows` 留着
/// (`hasPersistedMessages` 仍为 true),异步 `loadFirstPage` 用 `activeConversationID`
/// 守卫丢弃过期结果。在特定的交错时序下(慢读 + 快速来回切),会出现
/// 「`activeConversationID` 已是新对话、但 `historyRows` 仍残留旧对话内容」
/// 或「内容永不更新」的错配。UI 的 `historyBoundary`(首尾 id)若不变化,
/// 就永远不会触发滚到底,于是停在错乱偏移 → 空白。
///
/// 本套件不依赖 SwiftUI 渲染,直接在 ViewModel 层断言:
/// **任何时刻,`activeConversationID == selectedConversationID` 且
/// `historyRows` 里的消息必须属于当前选中的对话**。错配即复现。
@Suite("长对话切短对话空白复现 (ViewModel 层)", .serialized)
@MainActor
struct MessageListSwitchBlankReproTests {

    // MARK: - Helpers

    private func makeKernel(
        messages: MockMessageManager,
        conversations: MockConversationManager
    ) throws -> LumiKernel {
        let kernel = LumiKernel()
        try kernel.registerService(MessageManaging.self, messages)
        try kernel.registerService(ConversationManaging.self, conversations)
        try kernel.registerService(MessageStreaming.self, MockMessageStreaming())
        return kernel
    }

    /// 断言 viewmodel 当前展示的 historyRows 与选中对话一致(不错配)。
    private func expectConsistent(
        _ viewModel: MessageListViewModel,
        selectedID: UUID?,
        sourceComment: String
    ) {
        if let selectedID {
            let foreign = viewModel.historyRows.filter { $0.conversationID != selectedID }
            if !foreign.isEmpty {
                Issue.record(
                    "\(sourceComment): historyRows 残留了非当前对话的消息(数据错配 → 可能空白)。外来消息数=\(foreign.count)"
                )
            }
            #expect(foreign.isEmpty)
        }
    }

    // MARK: - Tests

    @Test("长对话切短对话:激活后 historyRows 必须属于短对话,无外来残留")
    func longToShort_noForeignRowsAfterSwitch() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let longID = UUID()
        let shortID = UUID()
        messages.seed(MockMessageManager.makeMessages(count: 300, conversationID: longID), conversationID: longID)
        messages.seed(MockMessageManager.makeMessages(count: 5, conversationID: shortID), conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations)
        let viewModel = MessageListViewModel(kernel: kernel)

        // 1. 先进入长对话并等其加载完。
        conversations.selectedConversationID = longID
        await viewModel.activate(conversationID: longID)
        #expect(viewModel.historyRows.count == 40, "长对话首屏应为 pageSize=40 条")

        // 2. 切到短对话。
        conversations.selectedConversationID = shortID
        await viewModel.activate(conversationID: shortID)

        // 3. 激活完成后:必须是短对话的 5 条,不能残留长对话消息。
        #expect(viewModel.historyRows.count == 5, "短对话应有 5 条,实际 \(viewModel.historyRows.count)")
        expectConsistent(viewModel, selectedID: shortID, sourceComment: "长切短后")
    }

    @Test("慢读下快速来回切:最终激活的对话必须是 historyRows 的归属对话")
    func rapidSwitch_underSlowRead_finalStateConsistent() async throws {
        let messages = MockMessageManager()
        messages.readDelayNs = 30_000_000  // 30ms 慢读,放大竞态窗口
        let conversations = MockConversationManager()
        let longID = UUID()
        let shortID = UUID()
        messages.seed(MockMessageManager.makeMessages(count: 300, conversationID: longID), conversationID: longID)
        messages.seed(MockMessageManager.makeMessages(count: 5, conversationID: shortID), conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations)
        let viewModel = MessageListViewModel(kernel: kernel)

        // 并发地快速来回切换多次(模拟用户快速点击不同对话)。
        // 每个 activate 都是 async,慢读会让它们的完成顺序与发起顺序交错。
        conversations.selectedConversationID = longID
        async let a: Void = viewModel.activate(conversationID: longID)
        conversations.selectedConversationID = shortID
        async let b: Void = viewModel.activate(conversationID: shortID)
        conversations.selectedConversationID = longID
        async let c: Void = viewModel.activate(conversationID: longID)
        _ = await (a, b, c)

        // 最终选中的是 longID,viewmodel 必须收敛到 longID 且内容属于 longID。
        #expect(viewModel.historyRows.count == 40, "最终应收敛到长对话 40 条,实际 \(viewModel.historyRows.count)")
        expectConsistent(viewModel, selectedID: longID, sourceComment: "快速来回切后")
    }

    @Test("切到短对话过程中:任何时刻 historyRows 都不能混入了非选中对话的消息")
    func duringSwitch_neverMixedConversations() async throws {
        let messages = MockMessageManager()
        messages.readDelayNs = 20_000_000
        let conversations = MockConversationManager()
        let longID = UUID()
        let shortID = UUID()
        messages.seed(MockMessageManager.makeMessages(count: 200, conversationID: longID), conversationID: longID)
        messages.seed(MockMessageManager.makeMessages(count: 4, conversationID: shortID), conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations)
        let viewModel = MessageListViewModel(kernel: kernel)

        conversations.selectedConversationID = longID
        await viewModel.activate(conversationID: longID)

        // 切换到短对话,在切换进行中多次采样,检查是否出现「混合对话」错配。
        conversations.selectedConversationID = shortID
        let switchTask = Task { await viewModel.activate(conversationID: shortID) }

        // 在 activate 完成前采样若干次。
        for _ in 0..<10 {
            // 采样时刻:如果 historyRows 非空,必须全部属于某一个对话
            // (要么还是旧 longID,要么已是新 shortID),绝不能两者混杂。
            let rows = viewModel.historyRows
            if !rows.isEmpty {
                let distinctConversations = Set(rows.map(\.conversationID))
                if distinctConversations.count > 1 {
                    Issue.record(
                        "切换中间态 historyRows 混入了多个对话的消息 → 渲染空白根源。涉及对话数=\(distinctConversations.count)"
                    )
                }
                #expect(distinctConversations.count <= 1)
            }
            try await Task.sleep(nanoseconds: 3_000_000)
        }
        try await switchTask.value

        // 收敛后属于短对话。
        expectConsistent(viewModel, selectedID: shortID, sourceComment: "采样结束收敛后")
    }

    @Test("isLoading 翻false后,hasPersistedMessages 与 historyRows 必须一致(不空假非空)")
    func afterLoading_consistentPersistedState() async throws {
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let longID = UUID()
        let shortID = UUID()
        messages.seed(MockMessageManager.makeMessages(count: 100, conversationID: longID), conversationID: longID)
        messages.seed(MockMessageManager.makeMessages(count: 6, conversationID: shortID), conversationID: shortID)

        let kernel = try makeKernel(messages: messages, conversations: conversations)
        let viewModel = MessageListViewModel(kernel: kernel)

        conversations.selectedConversationID = longID
        await viewModel.activate(conversationID: longID)
        conversations.selectedConversationID = shortID
        await viewModel.activate(conversationID: shortID)

        // 加载完成(isLoading==false)后:
        // hasPersistedMessages 与 historyRows 必须同真同假,不能出现
        // 「声称有持久消息、但行是空的」这种让 UI 走列表分支却渲染空白的状态。
        #expect(viewModel.isLoading == false)
        let hasPersisted = viewModel.hasPersistedMessages
        let hasRows = !viewModel.historyRows.isEmpty
        #expect(
            hasPersisted == hasRows,
            "isLoading 结束后状态不一致: hasPersistedMessages=\(hasPersisted) 但 historyRows.isEmpty=\(!hasRows)"
        )
        #expect(hasPersisted, "短对话有 6 条,应为非空")
    }
}
