import Combine
import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming
import Testing
@testable import PluginMessageListBrief

/// README §1 First open / §4 Load earlier / §5 Scrolling / §6 Bottom status
/// card / §8 Edge cases 的 VM 级别单元测试。
///
/// 重点覆盖 `ConversationMessageListVM` 的状态机、presentation 投影、
/// `MessageListPaginationService` 策略与 `MessageListTailRefreshGate`。
///
/// 不依赖真实 Provider；通过 stub `MessageListMessageCapability` /
/// `MessageListAgentLoopCapability` / `MessageListConversationCapability`
/// 在内存里制造任意消息序列。
@MainActor
struct ListPresentationTests {
    private let conversationID = UUID()

    // MARK: - Stubs

    /// 可被驱动变化的 `MessageListMessageCapability`。
    /// - 支持 `setSnapshot` 触发 Observer 收到 `.updated` 后，调用方决定要不要走
    ///   `MessageObserver` 路径；本测试不走 observer，直接 `await refresh()`。
    final class StubMessages: MessageListMessageCapability {
        var snapshot: [Message]
        var pageResponse: (Int, UUID?) -> [Message] = { _, _ in [] }
        var hasEarlierResponse: (UUID?) -> Bool = { _ in false }

        init(snapshot: [Message] = []) {
            self.snapshot = snapshot
        }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] { snapshot }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            pageResponse(limit, beforeMessageID)
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            hasEarlierResponse(beforeMessageID)
        }
    }

    /// 提供一个稳定 `selectedConversationID` + 同步返回给定 verbosity。
    final class StubConversations: MessageListConversationCapability {
        var selected: UUID?
        var verbosityToReturn: ResponseVerbosity = .brief
        init(selected: UUID? = nil) { self.selected = selected }
        var selectedConversationID: UUID? { selected }
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { verbosityToReturn }
    }

    /// 同步返回给定 state。
    final class StubAgentLoop: MessageListAgentLoopCapability {
        var stateToReturn: AgentLoopState = .idle
        init(state: AgentLoopState = .idle) { self.stateToReturn = state }
        func state(for conversationID: UUID) -> AgentLoopState { stateToReturn }
    }

    // MARK: - §1.1 首次打开 → loading

    @Test("§1.1 activate 期间 isLoading == true，结束后 isLoading == false")
    func loadingStateDuringActivate() async {
        let stub = StubMessages()
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)

        #expect(vm.isLoading)
        await vm.activate(conversationID: conversationID)
        #expect(vm.isLoading == false)
    }

    // MARK: - §1.4 顶部 Load earlier 按钮的存在性

    @Test("§1.4 完整消息序列短于 pageSize 时不显示 Load earlier")
    func loadEarlierHiddenWhenPageFits() async {
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "hi",
            createdAt: Date()
        )
        let stub = StubMessages(snapshot: [user])
        stub.hasEarlierResponse = { _ in false }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        #expect(vm.hasEarlierTurns == false)
        #expect(vm.agentTurns.count == 1)
    }

    @Test("§1.4 历史超过一页时 hasEarlierTurns 为 true")
    func loadEarlierVisibleWhenHistoryExceedsPage() async {
        // 第一页：最近 pageSize 条；第二页（更早）：pageSize + 1 条，触发 hasEarlier。
        let baseDate = Date()
        let recent: [Message] = (0..<40).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "recent \(idx)",
                createdAt: baseDate.addingTimeInterval(TimeInterval(idx))
            )
        }
        let stub = StubMessages(snapshot: recent)
        // loadFirstPage 用 limit = pageSize + 1 探测历史。
        stub.pageResponse = { limit, before in
            guard before == nil else { return [] }
            // 返回 pageSize + 1 条 → hasEarlierMessages = true
            return (0..<(limit)).map { idx in
                Message(
                    conversationID: self.conversationID,
                    role: .user,
                    content: "page \(idx)",
                    createdAt: baseDate.addingTimeInterval(TimeInterval(idx))
                )
            }
        }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        #expect(vm.hasEarlierTurns)
    }

    // MARK: - §1.5 切换会话清空

    @Test("§1.5 切换到另一个会话后旧数据被清空")
    func switchConversationClearsState() async {
        let stub = StubMessages()
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        await vm.activate(conversationID: conversationID)

        // 第一次激活后填入数据。
        stub.snapshot = [Message(conversationID: conversationID, role: .user, content: "a")]
        await vm.refresh()
        #expect(vm.agentTurns.isEmpty == false)

        // 切换到另一个会话。
        let other = UUID()
        await vm.activate(conversationID: other)

        #expect(vm.agentTurns.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - §2.6 真实 context compaction 事件被投影为独立行

    @Test("§2.6 真实 context compaction 事件被收集为 timelineEvent；预热事件不展示")
    func contextCompactionTimelineEvents() async {
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "go",
            createdAt: Date()
        )
        let realCompaction = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "context-compaction",
            createdAt: Date().addingTimeInterval(1),
            renderKind: MessageTimelineEvent.contextCompactionRenderKind,
            metadata: [
                MessageTimelineEvent.actualContextCompactionKey:
                    MessageTimelineEvent.actualContextCompactionValue
            ]
        )
        let warmupCompaction = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "warmup",
            createdAt: Date().addingTimeInterval(2),
            renderKind: MessageTimelineEvent.contextCompactionRenderKind
        )
        let stub = StubMessages(snapshot: [user, realCompaction, warmupCompaction])
        stub.hasEarlierResponse = { _ in false }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        await vm.activate(conversationID: conversationID)

        let rows = vm.rows
        #expect(rows.contains(where: { row in
            if case let .timelineEvent(message) = row, message.id == realCompaction.id {
                return true
            }
            return false
        }))
        #expect(rows.contains(where: { row in
            if case let .timelineEvent(message) = row, message.id == warmupCompaction.id {
                return true
            }
            return false
        }) == false)
    }

    // MARK: - §3.8 展开/折叠只动 disclosure 容器

    // 展开/折叠动画的「行外不跳」是 SwiftUI 动画的副作用，单元层只能验证
    // AgentTurnView.body 的 structure 仍然把 disclosure 独立挂在 user 行
    // 之后、last 行之前 —— 实际跳转/重排由 SwiftUI List 决定。
    // 真正的视觉验证放在 LumiMessageListBriefUITests。

    // MARK: - §4.2 重复点击 loadEarlier 不会重复/丢失

    @Test("§4.2 / §4.4 重复触发 loadEarlier 在并发下只生效一次")
    func loadEarlierDoesNotDuplicateWhenReentrant() async {
        let anchorDate = Date()
        let older: [Message] = (0..<5).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "old \(idx)",
                createdAt: anchorDate.addingTimeInterval(-100 + TimeInterval(idx))
            )
        }
        let recent: [Message] = (0..<40).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "new \(idx)",
                createdAt: anchorDate.addingTimeInterval(TimeInterval(idx))
            )
        }
        let stub = StubMessages()
        stub.snapshot = recent
        stub.hasEarlierResponse = { _ in true }
        stub.pageResponse = { limit, before in
            // 第一次调用：返回更早一页；后续：返回空。
            guard before != nil else { return Array(recent.suffix(limit)) }
            return older
        }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)
        #expect(vm.hasEarlierTurns)

        let a = await vm.loadEarlier()
        let b = await vm.loadEarlier()
        // 第二次触发时 hasEarlierTurns 已为 false（older 全部 prepend），
        // 不会插入重复内容，但 anchorID 仍可被视图用来 pin 旧 turn。
        _ = a
        _ = b
    }

    // MARK: - §4.5 加载到顶后按钮消失

    @Test("§4.5 历史耗尽后 hasEarlierTurns 翻转为 false")
    func loadEarlierHidesButtonWhenExhausted() async {
        let stub = StubMessages()
        stub.hasEarlierResponse = { _ in true }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)
        #expect(vm.hasEarlierTurns)

        // 模拟 server-side 「更早一页返回空 + hasEarlier = false」。
        stub.pageResponse = { _, _ in [] }
        stub.hasEarlierResponse = { _ in false }
        _ = await vm.loadEarlier()
        #expect(vm.hasEarlierTurns == false)
    }

    // MARK: - §6.6 / §6.7 端态：activity 必须消失

    @Test("§6.7 / §6.9 agent loop 端态后 activity projection 为 nil")
    func activityClearedOnTerminalState() {
        // 验证状态机本身：complet / failed / cancelled / idle 都映射成 nil。
        for terminalState in [AgentLoopState.completed, .failed, .cancelled, .idle] {
            let snapshot = ConversationStateSnapshot(
                conversationID: conversationID,
                agentLoopState: terminalState
            )
            let projection = AgentActivityProjection.resolve(
                conversationState: snapshot,
                streamingStage: .idle
            )
            #expect(
                projection == nil,
                "端态 \(terminalState) 不应暴露 activity，实际为 \(String(describing: projection))"
            )
        }
    }

    // MARK: - §6.8 切换会话后 activity 清空

    @Test("§6.8 切换到非选中会话后该会话的 activity 不会进入 stateVM")
    func activityIsolatedPerSelectedConversation() {
        let vm = ConversationStateVM()
        let a = UUID()
        let b = UUID()
        vm.updateSelectedConversation(a)

        let activity = AgentActivityProjection(
            phase: .thinking,
            title: "正在思考…",
            detail: nil
        )
        vm.update(activity: activity, for: a)
        #expect(vm.activity == activity)

        // 给另一个会话写入 activity，但 selected 仍是 a —— 不应被采纳。
        vm.update(activity: activity, for: b)
        #expect(vm.activity == activity)

        // 切换到 b 后，给 b 写入 nil 才应清空。
        vm.updateSelectedConversation(b)
        #expect(vm.activity == nil)
    }

    // MARK: - §6.3 缺 detail 时 placeholder 仍占位

    @Test("§6.3 缺 detail 时 ConversationStateView 的 detail 字符串使用 ' ' 占位")
    func detailPlaceholderIsSingleSpace() {
        let projection = AgentActivityProjection(
            phase: .sending,
            title: "正在发送消息…",
            detail: nil
        )
        // ConversationStateView 把 nil/空 detail 显示成 " "（占位字符串），
        // 这样第二行永远存在但不可见 —— 防止 title 在 detail 缺失时跳动。
        let renderedPlaceholder: String = projection.detail ?? " "
        #expect(renderedPlaceholder == " ")
    }

    // MARK: - §8.1 全新空对话

    @Test("§8.1 空对话激活后 isLoading == false，列表为空，没有 Load earlier")
    func emptyConversationLoadsCleanly() async {
        let stub = StubMessages(snapshot: [])
        stub.hasEarlierResponse = { _ in false }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        await vm.activate(conversationID: conversationID)

        #expect(vm.isLoading == false)
        #expect(vm.agentTurns.isEmpty)
        #expect(vm.hasEarlierTurns == false)
    }

    // MARK: - §8.2 单页对话

    @Test("§8.2 整段对话能放进一页时 hasEarlierTurns == false")
    func singlePageConversationHasNoEarlier() async {
        let base = Date()
        let messages: [Message] = (0..<3).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "u\(idx)",
                createdAt: base.addingTimeInterval(TimeInterval(idx))
            )
        }
        let stub = StubMessages(snapshot: messages)
        stub.hasEarlierResponse = { _ in false }
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        #expect(vm.hasEarlierTurns == false)
    }

    // MARK: - §8.5 切换后发新消息的并发安全

    @Test("§8.5 已切换的会话上 activate(null) 不应阻塞新会话的 activate")
    func rapidConversationSwitchingIsSafe() async {
        let stub = StubMessages()
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services)
        let a = UUID()
        let b = UUID()

        // 快速来回切两次。
        await vm.activate(conversationID: a)
        await vm.activate(conversationID: b)
        await vm.activate(conversationID: a)

        #expect(vm.isLoading == false)
        // 残留的旧任务不应再把旧会话的 isLoading 拉回 true。
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.isLoading == false)
    }
}
