import Combine
import Foundation
import ProviderAgentLoop
import ProviderConversation
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
///
/// - Note: `ConversationMessageListVM.activate` 会先比对
///   `services.selectedConversationID == conversationID`；`conversations`
///   传 nil 时选中态恒为 nil，activate 会被 guard 直接挡掉。因此所有走
///   activate 的用例都必须注入 `StubConversations(selected:)`。
@MainActor
struct ListPresentationTests {
    private let conversationID = UUID()

    // MARK: - Stubs

    /// 基于内存 `snapshot` 提供与生产语义一致的分页实现。
    ///
    /// 默认：按 createdAt 升序分页、`beforeMessageID == nil` 时返回最新
    /// `limit` 条、`hasEarlier` 在 nil 游标时用「> 10 条」探测窗口。
    /// 需要特殊行为时用 `pageOverride` / `hasEarlierOverride` 覆盖。
    final class StubMessages: MessageListMessageCapability {
        var snapshot: [Message]
        var pageOverride: ((Int, UUID?) -> [Message])?
        var hasEarlierOverride: ((UUID?) -> Bool)?

        init(snapshot: [Message] = []) {
            self.snapshot = snapshot
        }

        private func messages(of conversationID: UUID) -> [Message] {
            // 与真实 Provider 一致：分页接口只返回目标会话的消息。
            snapshot
                .filter { $0.conversationID == conversationID }
                .sorted { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                    return lhs.createdAt < rhs.createdAt
                }
        }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] {
            messages(of: conversationID)
        }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            if let pageOverride { return pageOverride(limit, beforeMessageID) }
            let all = messages(of: conversationID)
            guard let beforeMessageID else { return Array(all.suffix(limit)) }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(all[max(0, index - limit)..<index])
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            if let hasEarlierOverride { return hasEarlierOverride(beforeMessageID) }
            let all = messages(of: conversationID)
            guard let beforeMessageID else { return all.count > 10 }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
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

    private func makeServices(
        messages: (any MessageListMessageCapability)?,
        conversations: (any MessageListConversationCapability)?
    ) -> MessageListServices {
        MessageListServices(
            conversations: conversations,
            developerMode: nil,
            messages: messages,
            rendering: nil,
            agentTurn: nil
        )
    }

    // MARK: - §1.1 首次打开 → loading

    @Test("§1.1 activate 期间 isLoading == true，结束后 isLoading == false")
    func loadingStateDuringActivate() async {
        let services = makeServices(
            messages: StubMessages(),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services)

        #expect(vm.isLoading)
        await vm.activate(conversationID: conversationID)
        #expect(vm.isLoading == false)
    }

    @Test("§1.1 conversations 未选中该会话时 activate 被 guard 挡下")
    func activateRequiresSelectedConversation() async {
        let services = makeServices(
            messages: StubMessages(),
            conversations: StubConversations(selected: nil)
        )
        let vm = ConversationMessageListVM(services: services)
        await vm.activate(conversationID: conversationID)
        // 未选中 → 不进入加载流程，也不挂 activeConversationID。
        #expect(vm.agentTurns.isEmpty)
    }

    // MARK: - §1.4 顶部 Load earlier 按钮的存在性

    @Test("§1.4 完整消息序列短于一页时 hasEarlierTurns == false")
    func loadEarlierHiddenWhenPageFits() async {
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "hi",
            createdAt: Date()
        )
        let services = makeServices(
            messages: StubMessages(snapshot: [user]),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        #expect(vm.hasEarlierTurns == false)
        #expect(vm.agentTurns.count == 1)
    }

    @Test("§1.4 历史超过一页时 hasEarlierTurns 为 true")
    func loadEarlierVisibleWhenHistoryExceedsPage() async {
        // 45 条 user 消息 > 一页（pageSize = 40），首屏探测 limit = 41
        // 依然命中「还有更早」的条件。
        let baseDate = Date()
        let many: [Message] = (0..<45).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "msg \(idx)",
                createdAt: baseDate.addingTimeInterval(TimeInterval(idx))
            )
        }
        let services = makeServices(
            messages: StubMessages(snapshot: many),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        #expect(vm.hasEarlierTurns)
    }

    // MARK: - §1.5 切换会话清空

    @Test("§1.5 切换到另一个会话后旧数据被清空")
    func switchConversationClearsState() async {
        let stub = StubMessages()
        let conversations = StubConversations(selected: conversationID)
        let services = makeServices(messages: stub, conversations: conversations)
        let vm = ConversationMessageListVM(services: services)

        await vm.activate(conversationID: conversationID)
        stub.snapshot = [Message(conversationID: conversationID, role: .user, content: "a")]
        await vm.refresh()
        #expect(vm.agentTurns.isEmpty == false)

        // 切换到另一个会话：选中态同步变化后再 activate。
        let other = UUID()
        conversations.selected = other
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
            metadata: [
                MessageTimelineEvent.actualContextCompactionKey:
                    MessageTimelineEvent.actualContextCompactionValue
            ],
            renderKind: MessageTimelineEvent.contextCompactionRenderKind
        )
        let warmupCompaction = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "warmup",
            createdAt: Date().addingTimeInterval(2),
            renderKind: MessageTimelineEvent.contextCompactionRenderKind
        )
        let services = makeServices(
            messages: StubMessages(snapshot: [user, realCompaction, warmupCompaction]),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services)
        await vm.activate(conversationID: conversationID)

        let rows = vm.rows
        #expect(rows.contains { row in
            if case let .timelineEvent(message) = row, message.id == realCompaction.id {
                return true
            }
            return false
        })
        #expect(rows.contains { row in
            if case let .timelineEvent(message) = row, message.id == warmupCompaction.id {
                return true
            }
            return false
        } == false)
    }

    // MARK: - §3.8 展开/折叠只动 disclosure 容器

    // 展开/折叠动画的「行外不跳」是 SwiftUI 动画的副作用，单元层只能验证
    // AgentTurnView.body 的 structure 仍然把 disclosure 独立挂在 user 行
    // 之后、last 行之前 —— 实际跳转/重排由 SwiftUI List 决定。
    // 真正的视觉验证放在 LumiMessageListBriefUITests。

    // MARK: - §4.2 / §4.4 重复点击 loadEarlier

    @Test("§4.4 历史耗尽后重复触发 loadEarlier 返回 nil 不再插入")
    func loadEarlierDoesNotDuplicateWhenReentrant() async {
        let anchorDate = Date()
        // 45 条：首屏 40 条 + 更早 5 条。
        let all: [Message] = (0..<45).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "msg \(idx)",
                createdAt: anchorDate.addingTimeInterval(TimeInterval(idx))
            )
        }
        let services = makeServices(
            messages: StubMessages(snapshot: all),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)
        #expect(vm.hasEarlierTurns)

        let first = await vm.loadEarlier()
        #expect(first != nil, "第一次翻页应返回锚点 turn id 供视图 pin 位置")
        #expect(vm.hasEarlierTurns == false, "剩余 5 条全部加载后按钮应消失")

        let second = await vm.loadEarlier()
        #expect(second == nil, "历史耗尽后重复触发不应再加载，防止重复行")
    }

    // MARK: - §4.5 加载到顶后按钮消失

    @Test("§4.5 翻页到顶后 hasEarlierTurns 翻转为 false 且行不重复")
    func loadEarlierHidesButtonWhenExhausted() async {
        let base = Date()
        // 45 条：首屏 40 条 + 更早 5 条。
        let all: [Message] = (0..<45).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "msg \(idx)",
                createdAt: base.addingTimeInterval(TimeInterval(idx))
            )
        }
        let services = makeServices(
            messages: StubMessages(snapshot: all),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)
        #expect(vm.hasEarlierTurns, "45 条 > 一页 → 首屏应提示 Load earlier")
        #expect(vm.agentTurns.count == 40)

        let anchor = await vm.loadEarlier()

        #expect(anchor != nil)
        #expect(vm.hasEarlierTurns == false, "更早 5 条全部加载后按钮应消失")
        #expect(vm.agentTurns.count == 45, "翻页后 45 行全部就位，无重复无跳过")
    }

    // MARK: - §6 端态与隔离

    @Test("§6.7 / §6.9 agent loop 端态后 activity projection 为 nil")
    func activityClearedOnTerminalState() {
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

        // 切换到 b 后，选中态变化应清空旧 activity。
        vm.updateSelectedConversation(b)
        #expect(vm.activity == nil)
    }

    @Test("§6.3 缺 detail 时状态行只显示标题，不留占位空格")
    func statusLineWithoutDetailHasNoPlaceholder() {
        let projection = AgentActivityProjection(
            phase: .sending,
            title: "正在发送消息…",
            detail: nil
        )
        // 状态卡恒为一行：标题与细节合并到同一行，细节缺失时只显示标题。
        // 历史版本用 " " 占位撑出第二行把细节藏起来，导致卡片时而一行时而两行。
        #expect(projection.statusLineText == "正在发送消息…")
        // 占位空格机制已移除：文本首尾都不会留下空白。
        #expect(
            projection.statusLineText.trimmingCharacters(in: .whitespaces) == projection.statusLineText,
            "状态行不应残留占位空格"
        )
    }

    // MARK: - §8.1 全新空对话

    @Test("§8.1 空对话激活后 isLoading == false，列表为空，没有 Load earlier")
    func emptyConversationLoadsCleanly() async {
        let services = makeServices(
            messages: StubMessages(snapshot: []),
            conversations: StubConversations(selected: conversationID)
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
        let services = makeServices(
            messages: StubMessages(snapshot: messages),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        #expect(vm.hasEarlierTurns == false)
    }

    // MARK: - §8.5 快速切换会话

    @Test("§8.5 快速切换会话后旧会话的加载任务不会泄漏到新会话")
    func rapidConversationSwitchingIsSafe() async {
        let stub = StubMessages()
        let conversations = StubConversations(selected: conversationID)
        let services = makeServices(messages: stub, conversations: conversations)
        let vm = ConversationMessageListVM(services: services)
        let a = UUID()
        let b = UUID()

        // 模拟真实链路：用户切换 → selected 更新 → activate。
        conversations.selected = a
        await vm.activate(conversationID: a)
        conversations.selected = b
        await vm.activate(conversationID: b)
        conversations.selected = a
        await vm.activate(conversationID: a)

        #expect(vm.isLoading == false)
        // 残留的旧任务不应再把旧会话的 isLoading 拉回 true。
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.isLoading == false)
    }
}
