import LumiKernel
import LumiUI
import SwiftUI

/// Message List V1 View (brief / 简洁模式)
///
/// 当前 MessageListView 的完整实现,对应 verbosity = .brief。
/// 行渲染由 `MessageRowView` + verbosity 控制,本视图负责滚动、分页、流式跟随等全部逻辑。
struct MessageListV1View: View {
    @ObservedObject var kernel: LumiKernel
    @StateObject private var viewModel: MessageListViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近;用于决定新消息到达时是否自动滚到底部。
    @State private var isAtBottom = true

    // MARK: - Services

    private let scrollCoordinator = MessageListScrollCoordinator()

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _viewModel = StateObject(wrappedValue: MessageListViewModel(kernel: kernel))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                MessageLoadingView()
            } else if !viewModel.hasPersistedMessages {
                MessageEmptyStateView()
            } else {
                messageScrollView
            }
        }
        .task(id: viewModel.selectedConversationID) {
            // 切换会话:重置滚动位置,通知 viewmodel 加载最近一页。
            isAtBottom = true
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        // 外层 GeometryReader 捕获视口 max-Y,用于 isAtBottom 判断。
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    // Keep the paginated message window eager. LazyVStack can
                    // enter an AttributeGraph layout livelock when the live tail
                    // is replaced by its persisted history row at turn completion.
                    VStack(spacing: 0) {
                        historyRows(proxy: proxy)

                        if let message = viewModel.streamingRow {
                            MessageRowView(
                                kernel: kernel,
                                message: message,
                                verbosity: viewModel.verbosity
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
                    // 注入 V1「可折叠工具步骤组」的默认展开集合,供渲染层读取。
                    .environment(\.lumiActiveToolGroupIDs, viewModel.activeStepGroupMessageIDs)
                    .environment(\.lumiTurnActivitySummaries, viewModel.turnActivitySummaries)
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
                .task(id: viewModel.selectedConversationID) {
                    // 首屏数据就绪后,滚到最底部(无动画)。
                    scrollCoordinator.scrollToBottom(
                        proxy: proxy,
                        messages: viewModel.historyRows,
                        animated: false
                    )
                }
                .onLumiMessagesDidChange { eventConversationID in
                    guard MessageListNotificationFilter.shouldHandle(
                        eventConversationID: eventConversationID,
                        selectedConversationID: viewModel.selectedConversationID
                    ) else { return }

                    // 同一轮发送会连续产生 status/user/tool/assistant 事件。
                    // ViewModel 合并重叠刷新；只有拥有刷新且快照实际变化的调用方滚动。
                    let targetConversationID = viewModel.selectedConversationID
                    Task {
                        let wasAtBottom = isAtBottom
                        let didChange = await viewModel.refreshTail()
                        if didChange,
                           wasAtBottom,
                           viewModel.selectedConversationID == targetConversationID {
                            await scrollCoordinator.scrollToBottomAfterLayout(
                                proxy: proxy,
                                messages: viewModel.historyRows
                            )
                        }
                    }
                }
                // 流式跟随滚动:流式行内容变化时,
                // 若用户停在底部则跟随滚到底(无动画,避免高频 delta 抖动)。
                .onChange(of: viewModel.tailStreamingContent) { _, _ in
                    if isAtBottom {
                        proxy.scrollTo(MessageListScrollCoordinator.bottomAnchorID, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// Stable historical rows. The live streaming tail is rendered separately
    /// so token updates do not rebuild this collection.
    @ViewBuilder
    private func historyRows(proxy: ScrollViewProxy) -> some View {
        // 顶部"加载更早消息":仅在还有更早消息时显示。
        if viewModel.hasEarlierMessages {
            Button {
                Task { await loadEarlier(proxy: proxy) }
            } label: {
                if viewModel.isLoadingEarlier {
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

        ForEach(viewModel.historyRows) { message in
            MessageRowView(
                kernel: kernel,
                message: message,
                verbosity: viewModel.verbosity
            )
            .id(message.id)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
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
        guard let anchorID = await viewModel.loadEarlier(isAtBottom: isAtBottom) else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}
