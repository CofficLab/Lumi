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
    @State private var isAtBottom = true

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
            isAtBottom = true
            await turnViewModel.activate(conversationID: selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        // 外层 GeometryReader 捕获视口 max-Y,用于 isAtBottom 判断。
        GeometryReader { viewport in
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

                        bottomAnchor
                    }
                    // Keep a top inset without leaving scrollable space after
                    // the bottom anchor; the anchor must be the true content end.
                    .padding(.top, 4)
                }
                .onPreferenceChange(MessageListBottomAnchorPositionKey.self) { bottomMaxY in
                    let viewMaxY = viewport.frame(in: .global).maxY
                    // 仅在布尔值真正翻转时才写 state:底部锚点在滚动/流式刷新期间每帧
                    // 都会重报 maxY,若每帧都赋值会触发 body 重建 → preference 重发,
                    // 进而命中 "Bound preference ... tried to update multiple times per frame"。
                    let next = scrollCoordinator.resolveIsAtBottom(
                        bottomMaxY: bottomMaxY,
                        viewMaxY: viewMaxY,
                        current: isAtBottom
                    )
                    if next != isAtBottom {
                        isAtBottom = next
                    }
                }
                .task(id: selectedConversationID) {
                    // 首屏数据就绪后,滚到最底部(无动画)。
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
                    let targetConversationID = selectedConversationID
                    Task {
                        let wasAtBottom = isAtBottom
                        let didChange = await turnViewModel.refresh()
                        if didChange,
                           wasAtBottom,
                           selectedConversationID == targetConversationID {
                            await scrollCoordinator.scrollToBottomAfterLayout(
                                proxy: proxy,
                                messages: displayedHistoryMessages
                            )
                        }
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

    /// 底部锚点行:1pt 高的透明视图,报告其全局 max-Y。
    private var bottomAnchor: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: MessageListBottomAnchorPositionKey.self,
                    value: geometry.frame(in: .global).maxY
                )
        }
        // Keep the spacer inside the anchor so automatic scrolling includes
        // the visual bottom breathing room instead of leaving extra scrollable
        // content below the target.
        .frame(height: 16)
        .id(MessageListScrollCoordinator.bottomAnchorID)
        .accessibilityHidden(true)
    }

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
