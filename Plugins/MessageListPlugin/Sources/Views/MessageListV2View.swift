import LumiKernel
import LumiUI
import SwiftUI

/// Message List V2 View (standard / 标准模式)
///
/// 对应 verbosity = .standard 的消息列表视图。
/// 与 V1 共享相同的滚动、分页、流式跟随逻辑,行渲染由 `MessageRowView` + verbosity 控制。
struct MessageListV2View: View {
    @ObservedObject var kernel: LumiKernel
    @StateObject private var viewModel: MessageListViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近;用于决定新消息到达时是否自动滚到底部。
    ///
    /// 故意**不用 `@State`**:把它从 SwiftUI 的 invalidation 图里移除,
    /// 切断「bottomAnchor Preference → onPreferenceChange 写 state → body 重建
    /// → 几何重报 → 偏好同帧多次更新」这条反馈环。这条环在流式期间会被
    /// `scrollTo(.bottom)` + 行高增长推过临界点,导致 AttributeGraph 活锁
    /// (`Bound preference ... tried to update multiple times per frame`)与
    /// 异常巨大高度(`Invalid view geometry: height is greater than 2^45`)。
    ///
    /// 读路径(滚动跟随)直接读这个 box;切会话/发消息路径走 `.task` 重置。
    private let atBottomBox = AtBottomBox()

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
            atBottomBox.value = true
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Lazy so only visible history rows are materialized — the
                // window can hold hundreds of rows, each carrying a full
                // Markdown view tree, and eager materialization is the main
                // source of scroll jank in long conversations.
                //
                // This is safe because the live streaming tail is rendered
                // separately below (outside the history `ForEach`), so the
                // `ForEach` contains only stable, persisted ids. The earlier
                // AttributeGraph livelock arose when the streaming row (one
                // id) was swapped for its persisted counterpart (a different
                // id) inside the same eagerly-diffed collection; that swap no
                // longer touches the lazy `ForEach`.
                LazyVStack(spacing: 0) {
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

                    // 底部锚点行:纯占位,仅保留 scrollTo 用的稳定 id。
                    // 不再用 GeometryReader + PreferenceKey 报告全局坐标 ——
                    // 那套机制在流式(行高连续变化)下会让 LazyVStack 每帧做
                    // 尺寸变更平移,触发 AttributeGraph 活锁。是否在底部改由
                    // `ScrollViewBottomTracker`(观察 NSScrollView)判定。
                    Color.clear
                        .frame(height: 16)
                        .id(MessageListScrollCoordinator.bottomAnchorID)
                        .accessibilityHidden(true)
                }
                // Keep a top inset without leaving scrollable space after
                // the bottom anchor; the anchor must be the true content end.
                .padding(.top, 4)
                // 注入 V1「可折叠工具步骤组」的默认展开集合,供渲染层读取。
                .environment(\.lumiActiveToolGroupIDs, viewModel.activeStepGroupMessageIDs)
                .environment(\.lumiTurnActivitySummaries, viewModel.turnActivitySummaries)
            }
            // 「是否在底部」由观察 NSScrollView 的 tracker 报告,写入非 Observable
            // 的 `atBottomBox`,不触发 SwiftUI invalidation —— 切断布局反馈环。
            .background(ScrollViewBottomTracker { atBottomBox.value = $0 })
            .task(id: viewModel.selectedConversationID) {
                // 切会话重置:回到「在底部」语义,等首屏就绪后滚到底。
                atBottomBox.value = true
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
                // 流式期间用非动画滚动:动画 scrollTo 会不断重定目标、永不收敛。
                let targetConversationID = viewModel.selectedConversationID
                let wasAtBottom = atBottomBox.value
                Task {
                    let didChange = await viewModel.refreshTail()
                    if didChange,
                       wasAtBottom,
                       atBottomBox.value,
                       viewModel.selectedConversationID == targetConversationID {
                        await scrollCoordinator.scrollToBottomAfterLayout(
                            proxy: proxy,
                            messages: viewModel.historyRows,
                            animated: false
                        )
                    }
                }
            }
            // 流式跟随滚动:流式行内容变化时,
            // 若用户停在底部则跟随滚到底(无动画,避免高频 delta 抖动)。
            .onChange(of: viewModel.tailStreamingContent) { _, _ in
                if atBottomBox.value {
                    proxy.scrollTo(MessageListScrollCoordinator.bottomAnchorID, anchor: .bottom)
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

    /// 底部锚点行已内联到 `messageScrollView` 的 LazyVStack 末尾(纯 `Color.clear`
    /// 占位 + 稳定 id),不再需要独立的偏好报告视图。

    // MARK: - Pagination Trigger

    /// 向上翻页:View 只负责触发加载并把锚点行钉回视口顶部,
    /// 数据加载与窗口回收由 viewmodel 完成。
    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await viewModel.loadEarlier(isAtBottom: atBottomBox.value) else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}

/// 可变布尔盒子,刻意不实现 `ObservableObject`。
///
/// `MessageListV2View` 用它持有「是否在列表底部」这一滚动判定,使偏好回调写入
/// 它时**不会**进入 SwiftUI 的 invalidation 图 —— 这是切断底部锚点 Preference
/// 反馈环(`@State` → body 重建 → 偏好重报 → 活锁)的关键。
@MainActor
final class AtBottomBox {
    var value: Bool = true
}
