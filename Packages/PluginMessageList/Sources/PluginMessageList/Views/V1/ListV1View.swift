import Combine
import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// Message List V1 View (brief / 简洁模式)
///
/// 每个 AgentTurn 渲染成一组：触发该 turn 的用户消息 + 稳定的 turn 容器。
/// 运行中容器展示 status、思考、工具调用及流式正文（隐藏工具原始输出）；
/// turn 结束时动画折叠，只保留最终回复。历史终态 turn 首次加载时直接显示结果。
struct ListV1View: View {
    let services: MessageListServices
    @StateObject private var turnViewModel: ListV1ViewModel

    @LumiTheme private var theme

    /// 快照 + 事件刷新：init 同步读初值，之后由事件驱动更新。
    @State private var verbosity: ResponseVerbosity = .defaultVerbosity

    /// 选中对话变化观察者令牌：视图消失时释放（自动注销）。
    @State private var selectedObserverToken: (any SelectedConversationObserverHandle)?

    /// 用户是否停在列表底部附近；用于决定新消息到达时是否自动滚到底部。
    ///
    /// 故意不用 `@State`，以切断底部锚点 Preference → body 重建 → 偏好重报的
    /// 反馈环（详见 `ListV2View` 同名注释）。
    private let atBottomBox = AtBottomBox()

    // MARK: - Services

    private let scrollCoordinator = MessageListScrollCoordinator()

    init(services: MessageListServices) {
        self.services = services
        _turnViewModel = StateObject(wrappedValue: ListV1ViewModel(services: services))
        _verbosity = State(
            initialValue: services.verbosity(for: services.selectedConversationID)
        )
    }

    var body: some View {
        Group {
            if turnViewModel.isLoading {
                MessageLoadingView()
            } else if !turnViewModel.hasVisibleContent {
                MessageEmptyStateView(services: services)
            } else {
                messageScrollView
            }
        }
        // 快照 + 事件刷新：首次出现/视图重建加载当前会话，
        // 选中切换与 verbosity 变化由事件驱动。
        .task {
            // 首次出现/容器切换重建：重置滚动位置，加载当前选中会话。
            atBottomBox.value = true
            await turnViewModel.activate(conversationID: selectedConversationID)
        }
        // 选中对话变化：callback 机制（替代旧版 `.lumiSelectedConversationDidChange` 通知）。
        // 视图消失时释放令牌自动注销，无需手动反注册。
        .onAppear {
            selectedObserverToken = services.addSelectedConversationObserver { newID in
                atBottomBox.value = true
                verbosity = services.verbosity(for: newID)
                Task { @MainActor in
                    await turnViewModel.activate(conversationID: newID)
                }
            }
        }
        .onDisappear {
            selectedObserverToken?.cancel()
            selectedObserverToken = nil
        }
        // 会话设置变化（verbosity 等）：订阅 ConversationManaging 窄播
        // （替代旧版 `.lumiConversationsDidChange` 通知）。
        .onReceive(services.conversationsChangesPublisher) { _ in
            refreshVerbosity()
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            // List(NSTableView)自带 cell 复用：只有可见行被 materialize。
            //
            // Safe because the list is pure database-driven: the `ForEach`
            // contains only stable, persisted ids. There is no live streaming
            // row swapping a transient id for its persisted counterpart inside
            // the same collection (streaming content only lands here once it
            // is persisted at turn end).
            List {
                historyRows(proxy: proxy)

                // 底部锚点行：纯占位 + 稳定 id（供 scrollTo 用），不再报偏好。
                // 是否在底部由 `ScrollViewBottomTracker` 观察 NSScrollView 判定。
                Color.clear
                    .frame(height: 16)
                    .id(MessageListScrollCoordinator.bottomAnchorID)
                    .accessibilityHidden(true)
                    .plainMessageListRow(insets: EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // 「是否在底部」由观察 NSScrollView 的 tracker 报告，写入非 Observable
            // 的 `atBottomBox`，不触发 SwiftUI invalidation —— 切断布局反馈环。
            .background(ScrollViewBottomTracker { atBottomBox.value = $0 })
            // ViewModel 在空态也监听消息变化，可能会先于下方 View 事件完成刷新。
            // 因此再按实际可见行边界跟随一次，确保用户消息/Status 更新始终可见。
            .onChange(of: visibleRowIDs) { _, _ in
                guard atBottomBox.value else { return }
                Task { @MainActor in
                    await scrollCoordinator.scrollToBottomAfterLayout(
                        proxy: proxy,
                        messages: displayedHistoryMessages,
                        animated: false,
                        condition: { atBottomBox.value }
                    )
                }
            }
            // 切会话/首屏加载完成：messageScrollView 在 isLoading 翻转时会销毁重建，
            // 重建后 onAppear 触发。此时 atBottomBox 已被事件 handler 重置为 true，
            // 内容就绪即滚到底 —— 不抢跑 scroll（避免打在旧会话布局上作废）。
            .onAppear {
                if atBottomBox.value {
                    scrollCoordinator.scrollToBottom(
                        proxy: proxy,
                        messages: displayedHistoryMessages,
                        animated: false
                    )
                }
            }
            .onReceive(messageChangesPublisher) { _ in
                handleMessagesDidChange(proxy: proxy)
            }
        }
    }

    /// 落库消息变化的窄播（替代旧版 `.lumiMessagesDidChange` 通知）。
    private var messageChangesPublisher: AnyPublisher<Void, Never> {
        guard let messages = services.messages else {
            return Empty().eraseToAnyPublisher()
        }
        return messages.objectWillChange
            .map { _ in () }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// 消息变化处理：合并刷新 + 按需滚动（与旧版 `onLumiMessagesDidChange` 行为一致）。
    private func handleMessagesDidChange(proxy: ScrollViewProxy) {
        guard MessageListNotificationFilter.shouldHandle(
            eventConversationID: nil,
            selectedConversationID: selectedConversationID
        ) else { return }

        // 同一轮发送会连续产生 status/user/tool/assistant 事件。
        // ViewModel 合并重叠刷新；只有拥有刷新且快照实际变化的调用方滚动。
        // 流式期间用非动画滚动，避免动画 scrollTo 永不收敛。
        let targetConversationID = selectedConversationID
        let wasAtBottom = atBottomBox.value
        // 记录刷新前最后一条用户消息 id，用于判定「用户本人刚发送了新消息」。
        let previousLastUserMessageID = displayedHistoryMessages
            .last(where: { $0.role == .user })?.id
        Task {
            let didChange = await turnViewModel.refresh()
            guard didChange, selectedConversationID == targetConversationID else { return }

            // 用户本人发送：像常见聊天软件一样无条件滚到底，
            // 并把底部判定重置回 true（tracker 会随后按几何自校准）。
            let lastUserMessageID = displayedHistoryMessages
                .last(where: { $0.role == .user })?.id
            let isOwnSend = lastUserMessageID != nil
                && lastUserMessageID != previousLastUserMessageID
            guard wasAtBottom || isOwnSend else { return }
            if isOwnSend { atBottomBox.value = true }

            // 不再用 `atBottomBox.value` 作为实时滚动条件：新行追加后
            // 首次 scrollTo 常落点偏上，此时内容底沿超出视口 > 离开阈值
            // 会让 tracker 把 atBottomBox 翻成 false，从而取消本应修正
            // 落点的 +100ms 重试，导致列表停在半路（「有时不滚到底部」）。
            await scrollCoordinator.scrollToBottomAfterLayout(
                proxy: proxy,
                messages: displayedHistoryMessages,
                animated: false,
                condition: { true }
            )
        }
    }

    /// List 只排列多个 AgentTurnView；消息展示完全由 AgentTurnView 负责。
    @ViewBuilder
    private func historyRows(proxy: ScrollViewProxy) -> some View {
        if turnViewModel.hasEarlierTurns {
            loadEarlierButton(isLoading: turnViewModel.isLoadingEarlier) {
                Task { await loadEarlier(proxy: proxy) }
            }
            .plainMessageListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        ForEach(turnViewModel.agentTurns) { item in
            AgentTurnView(
                services: services,
                item: item,
                lastAgentTurnID: turnViewModel.agentTurns.last?.id,
                verbosity: verbosity
            )
            .id(item.id)
            .plainMessageListRow()
        }
    }

    private func loadEarlierButton(
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Text(LumiPluginLocalization.string("Load earlier messages"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var displayedHistoryMessages: [ProviderMessage.Message] { turnViewModel.displayMessages }

    private var visibleRowIDs: [UUID] {
        displayedHistoryMessages.map(\.id)
    }

    private var selectedConversationID: UUID? {
        services.selectedConversationID
    }

    /// 事件驱动刷新 verbosity 快照（路由与行渲染共用）。
    private func refreshVerbosity() {
        verbosity = services.verbosity(for: selectedConversationID)
    }

    // MARK: - Pagination Trigger

    /// 向上翻页：View 只负责触发加载并把锚点行钉回视口顶部，
    /// 数据加载与窗口回收由 viewmodel 完成。
    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await turnViewModel.loadEarlier() else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}
