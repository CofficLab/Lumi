import LumiKernel
import LumiUI
import SwiftUI

/// Message List V2 View (standard / 标准模式)
struct ListV2View: View {
    let kernel: LumiKernel
    @StateObject private var viewModel: ListViewModel

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

    // MARK: - Live-Resize 降级渲染

    /// 窗口是否在 live resize 中。为 true 时 LazyVStack 渲染轻量占位行而非富文本,
    /// 使 SwiftUI 在 resize 期间不再遍历昂贵的富文本子树 layout。
    /// 翻转触发 body 重建一次(有意为之),重建后子树已是轻量占位,后续帧零开销。
    @State private var isLiveResizing: Bool = false

    // MARK: - Services

    private let scrollCoordinator = MessageListScrollCoordinator()

    /// 内容就绪信号：historyRows 首尾消息 id 变化时 +1。
    ///
    /// 仅用于驱动「切会话/首屏内容出现后滚到底」。
    /// 之所以不用 `.task(id:)` 里抢跑 scroll：loadFirstPage 是异步 DB 读,
    /// 慢时会超过重试窗口,导致 scroll 打在旧会话布局上作废、新内容到后再无人 scroll → 空白。
    /// 改为「内容首尾 id 变化且锚点已布局」时再 scroll,锚点存在即内容已就绪,必然有效。
    @State private var scrollTick: Int = 0

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _viewModel = StateObject(wrappedValue: ListViewModel(kernel: kernel))
    }

    var body: some View {
        ZStack {
            if viewModel.hasPersistedMessages {
                messageScrollView
            } else {
                MessageEmptyStateView()
            }
            if viewModel.isLoading {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        // Live-resize 检测:翻转 isLiveResizing,驱动 LazyVStack 在 resize 期间
        // 降级为轻量占位行,移除富文本子树以消除 layout 遍历开销。
        .background(LiveResizeDetector(isLiveResizing: $isLiveResizing))
        // 快照 + 事件刷新(同 ChatHeaderView 模式):不订阅 kernel 的 objectWillChange。
        // - `.task` 仅在首次出现/视图重建时加载当前会话;
        // - 选中切换由 `.lumiSelectedConversationDidChange` 事件驱动(事件发出时
        //   `selectedConversationID` 已是新值,直接传给 activate,无需读 kernel);
        // - 会话设置(verbosity 等)变化由 `.lumiConversationsDidChange` 驱动轻量重建。
        .task {
            // 首次出现/容器切换重建:重置滚动位置,加载当前选中会话。
            atBottomBox.value = true
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
        .onLumiSelectedConversationDidChange { newID in
            atBottomBox.value = true
            Task { @MainActor in
                await viewModel.activate(conversationID: newID)
            }
        }
        .onLumiConversationsDidChange {
            viewModel.refreshConversationSettingsIfNeeded()
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
                        if isLiveResizing {
                            MessageResizePlaceholder(message: message)
                                .id(message.id)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                        } else {
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

                    // 底部锚点行:纯占位,仅保留 scrollTo 用的稳定 id。
                    // 不再用 GeometryReader + PreferenceKey 报告全局坐标 ——
                    // 那套机制在流式(行高连续变化)下会让 LazyVStack 每帧做
                    // 尺寸变更平移,触发 AttributeGraph 活锁。是否在底部改由
                    // `ScrollViewBottomTracker`(观察 NSScrollView)判定。
                    //
                    // scrollTick 变化(切会话/首屏内容已加载)时在此滚到底。
                    // 挂在锚点上是因为:锚点是内容末尾,它存在即内容已完成布局,
                    // 此时 scrollTo 必然有效 —— 这是修复「切换对话偶发空白」的关键。
                    Color.clear
                        .frame(height: 16)
                        .id(MessageListScrollCoordinator.bottomAnchorID)
                        .accessibilityHidden(true)
                        .onChange(of: scrollTick) { _, _ in
                            proxy.scrollTo(
                                MessageListScrollCoordinator.bottomAnchorID,
                                anchor: .bottom
                            )
                        }
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
            // live-resize 的滚动位置恢复完全由 tracker 在 AppKit 层负责:
            // - 底部场景:tracker 持续把 contentOffset 钉到 documentView 底部,
            //   直到富文本行 lazy materialize 完成、几何真正稳定,期间 suppress
            //   onChange 防止 atBottomBox 被污染。
            // - 非底部场景:tracker 恢复 resize 前保存的 contentOffset。
            // 宿主无需在 onLiveResizeEnd 里做任何滚动。
            .background(
                ScrollViewBottomTracker(
                    onChange: { atBottomBox.value = $0 }
                )
            )
            // 切会话只重置「在底部」语义,不在此抢跑 scroll。
            // 旧实现立刻 scroll,但 loadFirstPage 是异步 DB 读,慢时 scroll 打在
            // 旧会话布局上作废、新内容到后再无人 scroll → 空白。改为下方
            // historyBoundary 变化驱动 scrollTick,内容就绪后由锚点滚到底。
            // (atBottomBox 重置已由外层 .onLumiSelectedConversationDidChange 负责。)
            // 内容首尾消息 id 变化 = 新会话首屏/尾部刷新已加载。
            // 只要用户在底部,就推进 scrollTick,触发锚点滚到底。
            .onChange(of: historyBoundary) { _, _ in
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            // 兜底:锚点出现(内容从无到有)时也补一次,覆盖首屏/慢加载。
            .onAppear {
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            // 注意:live-resize 的滚动位置保持由 `LiveResizeScrollRestorer` 统一负责,
            // 这里不再用 onChange(isLiveResizing) 推 scrollTick,避免与 restorer 冲突。
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
                            animated: false,
                            condition: { [weak atBottomBox] in
                                atBottomBox?.value == true
                            }
                        )
                    }
                }
            }
            // 流式跟随滚动:流式行内容变化时,
            // 若用户停在底部则跟随滚到底(无动画,避免高频 delta 抖动)。
            // 走 coordinator 的 scrollToBottom,带重试以兼容 macOS 14 LazyVStack
            // 未布局时 scrollTo 静默失败的问题。
            // condition 确保用户手动滚离底部后,100ms 重试不会把他们拉回底部。
            .onChange(of: viewModel.tailStreamingContent) { _, _ in
                scrollCoordinator.scrollToBottom(
                    proxy: proxy,
                    messages: viewModel.historyRows,
                    animated: false,
                    condition: { [weak atBottomBox] in
                        atBottomBox?.value == true
                    }
                )
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
            if isLiveResizing {
                // Live-resize 降级:渲染轻量占位行,移除富文本子树。
                // 这样 SwiftUI 在 resize 每帧不再遍历昂贵的 Markdown layout。
                MessageResizePlaceholder(message: message)
                    .id(message.id)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            } else {
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
    }

    /// 底部锚点行已内联到 `messageScrollView` 的 LazyVStack 末尾(纯 `Color.clear`
    /// 占位 + 稳定 id),不再需要独立的偏好报告视图。

    /// 内容首尾消息 id 对,作为「首屏/新会话内容已加载」的就绪信号。
    ///
    /// 用首尾 id 而非整个数组:流式 token 只改内容不改 id,不会误触发;
    /// 而切会话/尾部刷新导致首尾 id 变化时,才真正需要重新滚到底。
    private var historyBoundary: HistoryBoundary {
        HistoryBoundary(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
    }

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

/// 消息列表首尾 id 对,用于 `onChange` 检测「首屏/新会话内容已加载」。
/// 元组无法遵循 `Equatable`,故用结构体承载。
private struct HistoryBoundary: Equatable {
    let first: UUID?
    let last: UUID?
}
