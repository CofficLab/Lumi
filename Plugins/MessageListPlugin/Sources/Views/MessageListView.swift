import LumiKernel
import LumiUI
import SwiftUI

/// Message List View
///
/// 纯展示组件:只负责**展示、滚动、分页触发**。
/// 行序列的合并(流式临时行 / 状态行)、分页数据加载、详细程度等"消息知识"
/// 全部由自带 viewmodel `MessageListViewModel` 承担 —— 本视图只面对已准备好的
/// `viewModel.displayRows` 行序列,不区分行的类型与来源。
struct MessageListView: View {
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

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    var body: some View {
        Group {
            if selectedConversationID == nil {
                NoConversationSelectedView()
            } else if viewModel.isLoading {
                MessageLoadingView()
            } else if !viewModel.hasPersistedMessages {
                MessageEmptyStateView()
            } else {
                messageScrollView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .task(id: selectedConversationID) {
            // 切换会话:重置滚动位置,通知 viewmodel 加载最近一页。
            isAtBottom = true
            await viewModel.activate(conversationID: selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        // 外层 GeometryReader 捕获视口 max-Y,用于 isAtBottom 判断。
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    // 静态历史使用 LazyVStack,避免把当前窗口内的所有消息都创建并布局。
                    // 流式期间暂时保留 VStack:displayRows 会以 token 频率变化,后续再把
                    // 流式尾部拆成独立视图,从而也能在流式场景安全使用 LazyVStack。
                    Group {
                        if viewModel.isStreaming {
                            VStack(spacing: 0) {
                                messageRows(proxy: proxy)
                            }
                        } else {
                            LazyVStack(spacing: 0) {
                                messageRows(proxy: proxy)
                            }
                        }
                    }
                    .padding(.vertical, 4)
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
                .task(id: selectedConversationID) {
                    // 首屏数据就绪后,滚到最底部(无动画)。
                    scrollCoordinator.scrollToBottom(
                        proxy: proxy,
                        messages: viewModel.displayRows,
                        animated: false
                    )
                }
                .onLumiMessagesDidChange {
                    // 尾部新消息/流式落库:通知 viewmodel 刷新尾部;若用户在底部则滚到底。
                    Task {
                        let wasAtBottom = isAtBottom
                        await viewModel.refreshTail()
                        if wasAtBottom {
                            await scrollCoordinator.scrollToBottomAfterLayout(
                                proxy: proxy,
                                messages: viewModel.displayRows
                            )
                        }
                    }
                }
                // 流式跟随滚动:流式行内容变化时,
                // 若用户停在底部则跟随滚到底(无动画,避免高频 delta 抖动)。
                .onChange(of: viewModel.tailStreamingContent) { _ in
                    if isAtBottom {
                        proxy.scrollTo(MessageListScrollCoordinator.bottomAnchorID, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// Shared row content for the eager streaming stack and virtualized history stack.
    @ViewBuilder
    private func messageRows(proxy: ScrollViewProxy) -> some View {
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

        ForEach(viewModel.displayRows) { message in
            MessageRowView(
                kernel: kernel,
                message: message,
                verbosity: viewModel.verbosity
            )
            .id(message.id)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }

        // 底部锚点:通过它的几何位置判断 isAtBottom。
        bottomAnchor
            .padding(.bottom, 24)
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
        .frame(height: 1)
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
