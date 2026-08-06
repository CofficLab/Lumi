import LumiKernel
import LumiUI
import SwiftUI

/// Message List V1 View (brief / 简洁模式)
///
/// 历史中每个 AgentTurn 只展示最终结论；运行中的 Turn 只展示一条动态 status。
/// 流式正文、工具调用和工具结果均不进入 V1 展示投影。
struct MessageListV1View: View {
    @ObservedObject var kernel: LumiKernel
    @StateObject private var turnViewModel: MessageListV1ViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近;用于决定新消息到达时是否自动滚到底部。
    ///
    /// 故意不用 `@State`,以切断底部锚点 Preference → body 重建 → 偏好重报的
    /// 反馈环(详见 `MessageListV2View` 同名注释)。
    private let atBottomBox = AtBottomBox()

    // MARK: - Services

    private let scrollCoordinator = MessageListScrollCoordinator()

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _turnViewModel = StateObject(wrappedValue: MessageListV1ViewModel(kernel: kernel))
    }

    var body: some View {
        Group {
            if turnViewModel.isLoading {
                MessageLoadingView()
            } else if !turnViewModel.hasVisibleContent {
                MessageEmptyStateView()
            } else {
                messageScrollView
            }
        }
        .task(id: selectedConversationID) {
            // 切换会话:重置滚动位置,通知 viewmodel 加载最近一页。
            atBottomBox.value = true
            await turnViewModel.activate(conversationID: selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Lazy so only visible conclusion rows are materialized; see
                // MessageListV2View for the rationale (stable ids only, live
                // status rendered outside the history `ForEach`).
                LazyVStack(spacing: 0) {
                    historyRows(proxy: proxy)

                    if let message = turnViewModel.statusMessage {
                        MessageRowView(
                            kernel: kernel,
                            message: message,
                            verbosity: verbosity
                        )
                        .id(message.id)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }

                    // 底部锚点行:纯占位 + 稳定 id(供 scrollTo 用),不再报偏好。
                    // 是否在底部由 `ScrollViewBottomTracker` 观察NSScrollView 判定,
                    // 避免 GeometryReader + Preference 在流式下触发 LazyVStack 活锁。
                    Color.clear
                        .frame(height: 16)
                        .id(MessageListScrollCoordinator.bottomAnchorID)
                        .accessibilityHidden(true)
                }
                // Keep a top inset without leaving scrollable space after
                // the bottom anchor; the anchor must be the true content end.
                .padding(.top, 4)
            }
            // 「是否在底部」由观察 NSScrollView 的 tracker 报告,写入非 Observable
            // 的 `atBottomBox`,不触发 SwiftUI invalidation —— 切断布局反馈环。
            .background(ScrollViewBottomTracker { atBottomBox.value = $0 })
            .task(id: selectedConversationID) {
                // 切会话重置:回到「在底部」语义,等首屏就绪后滚到底。
                atBottomBox.value = true
                scrollCoordinator.scrollToBottom(
                    proxy: proxy,
                    messages: displayedHistoryMessages,
                    animated: false
                )
            }
            .onLumiMessagesDidChange { eventConversationID in
                guard MessageListNotificationFilter.shouldHandle(
                    eventConversationID: eventConversationID,
                    selectedConversationID: selectedConversationID
                ) else { return }

                // 同一轮发送会连续产生 status/user/tool/assistant 事件。
                // ViewModel 合并重叠刷新；只有拥有刷新且快照实际变化的调用方滚动。
                // 流式期间用非动画滚动,避免动画 scrollTo 永不收敛。
                let targetConversationID = selectedConversationID
                let wasAtBottom = atBottomBox.value
                Task {
                    let didChange = await turnViewModel.refresh()
                    if didChange,
                       wasAtBottom,
                       atBottomBox.value,
                       selectedConversationID == targetConversationID {
                        await scrollCoordinator.scrollToBottomAfterLayout(
                            proxy: proxy,
                            messages: displayedHistoryMessages,
                            animated: false
                        )
                    }
                }
            }
        }
    }

    /// Stable conclusion rows. Live work is represented separately by one status.
    @ViewBuilder
    private func historyRows(proxy: ScrollViewProxy) -> some View {
        if turnViewModel.usesTurnProjection {
            turnSummaryRows(proxy: proxy)
        } else {
            legacyConclusionRows
        }
    }

    @ViewBuilder
    private func turnSummaryRows(proxy: ScrollViewProxy) -> some View {
        if turnViewModel.hasEarlierTurns {
            loadEarlierButton(isLoading: turnViewModel.isLoadingEarlier) {
                Task { await loadEarlier(proxy: proxy) }
            }
        }

        ForEach(turnViewModel.items) { item in
            MessageRowView(
                kernel: kernel,
                message: item.message,
                verbosity: verbosity
            )
            .id(item.id)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var legacyConclusionRows: some View {
        ForEach(turnViewModel.conclusionMessages) { message in
            MessageRowView(
                kernel: kernel,
                message: message,
                verbosity: verbosity
            )
            .id(message.id)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
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
                Text(LumiPluginLocalization.string("Load earlier messages", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var displayedHistoryMessages: [LumiChatMessage] { turnViewModel.displayMessages }

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    private var verbosity: LumiResponseVerbosity {
        kernel.conversationManager?
            .verbosity(for: selectedConversationID) ?? .defaultVerbosity
    }

    /// 底部锚点行已内联到 `messageScrollView` 的 LazyVStack 末尾(纯 `Color.clear`
    /// 占位 + 稳定 id),不再需要独立的偏好报告视图。

    // MARK: - Pagination Trigger

    /// 向上翻页:View 只负责触发加载并把锚点行钉回视口顶部,
    /// 数据加载与窗口回收由 viewmodel 完成。
    private func loadEarlier(proxy: ScrollViewProxy) async {
        let anchorID: UUID?
        anchorID = turnViewModel.usesTurnProjection
            ? await turnViewModel.loadEarlier()
            : nil
        guard let anchorID else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}
