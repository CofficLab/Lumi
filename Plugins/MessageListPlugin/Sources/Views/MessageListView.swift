import LumiKernel
import LumiUI
import SwiftUI

/// Message List View
///
/// Displays the chat message list for the selected conversation.
///
/// 采用游标分页:首屏只加载最近一页(pageSize 条),向上滚动到顶部时可加载更早的一页,
/// 内存中最多保留 `maxRetainedCount` 条,超出则丢弃尾部(较新、远离可视区的)消息,
/// 使内存占用与消息总量无关。数据库读取在后台线程执行,避免阻塞主线程。
struct MessageListView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    /// 当前内存中的消息,按时间升序排列(最老在前、最新在后)。
    @State private var messages: [LumiChatMessage] = []
    /// 顶部是否还有更早的消息未加载。
    @State private var hasEarlierMessages = false
    /// 正在加载更早一页(顶部按钮的 loading 态)。
    @State private var isLoadingEarlier = false
    /// 首屏 loading:切换会话时为 true,首屏数据就绪后置 false。
    @State private var isLoading = true
    /// 用户是否停在列表底部附近;用于决定新消息到达时是否自动滚到底部。
    @State private var isAtBottom = true
    /// 切换会话时记录的目标会话,用于丢弃过期的后台读结果。
    @State private var activeConversationID: UUID?

    @State private var showRawMessage = false

    private let pageSize = 40
    /// 内存中最多保留的消息条数;超出则丢弃尾部(用户在向上翻历史时)。
    private let maxRetainedCount = 300

    /// 底部锚点行的 id,用于 isAtBottom 检测和 scrollTo。
    private static let bottomAnchorID = "message-list-bottom-anchor"

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    /// 当前会话是否正在发送。
    private var isSending: Bool {
        kernel.messageSender?.isSending(for: selectedConversationID) ?? false
    }

    /// 仅用于展示的消息列表。
    ///
    /// 在真实消息(`messages`)末尾拼接两类**不写库**的临时行,因此分页/尾部合并/裁剪
    /// 逻辑仍只基于真实消息,不会被临时行干扰:
    /// 1. 流式临时行:来自 `kernel.messageStreaming`(独立稳定 id,与落库行永不冲突)。
    ///    用于正文生成阶段——内容本身就是进度反馈。
    /// 2. 发送中状态行:来自 `kernel.messageSender`(数据层构造,UI 只读取)。
    ///    在**发送阶段**(尚未收到 LLM 响应)或**思考阶段**(展示实时思考文本)显示;
    ///    正文生成阶段由流式行体现,不再叠加状态行。
    private var displayMessages: [LumiChatMessage] {
        guard let conversationID = selectedConversationID else { return messages }
        var rows = messages
        let streaming = kernel.messageStreaming
        // 流式临时行(仅当属于当前会话;切会话时自动被过滤,无需额外清理)。
        let streamingRow = streaming?.currentStreamingRow
        if let streamingRow, streamingRow.conversationID == conversationID {
            rows.append(streamingRow)
        }
        // 状态行显示条件:
        // - 没有流式行(发送阶段),或
        // - 处于思考阶段(thinking)——此时流式行虽存在但正文为空,思考文本走状态行展示。
        // 正文生成阶段(generating)有流式行的正文,不再叠加状态行。
        let stage = streaming?.currentStage ?? .idle
        let showStatus = streamingRow == nil || stage == .thinking
        if showStatus, let statusRow = kernel.messageSender?.currentStatusRow(for: conversationID) {
            rows.append(statusRow)
        }
        return rows
    }

    var body: some View {
        Group {
            if isLoading {
                MessageLoadingView()
            } else if messages.isEmpty && !isSending {
                MessageEmptyStateView()
            } else {
                messageScrollView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .task(id: selectedConversationID) {
            // 切换会话:重置状态,加载最近一页。
            activeConversationID = selectedConversationID
            isLoading = true
            isAtBottom = true
            await loadFirstPage()
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        // 外层 GeometryReader 捕获视口 max-Y,用于 isAtBottom 判断。
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    // 用 VStack 而非 LazyVStack:本列表数据源在流式输出期间会高频变化
                    // (每条 .lumiMessagesDidChange 都会 refreshTail 重写 messages 尾部)。
                    // LazyVStack 在数据源高频变化时会陷入主线程重布局活锁——每帧反复
                    // applyNodes/update 视口内行、重建 _LazyLayoutViewCache,导致 CPU 100%
                    // 且内存随 _LazyLayout_Subview 持续拷贝分配而单调上涨。
                    // VStack 一次性构建所有行,只对 messages 变化做一次 diff,反而稳定。
                    // 列表条数已由游标分页(pageSize=40)和 renderer 两层缓存控制,
                    // 一次性渲染几十行无压力,无需 LazyVStack 惰性化。
                    VStack(spacing: 0) {
                        // 顶部"加载更早消息":仅在还有更早消息时显示。
                        if hasEarlierMessages {
                            Button {
                                Task { await loadEarlier(proxy: proxy) }
                            } label: {
                                if isLoadingEarlier {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Load earlier messages")
                                        .font(.appCaption)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        ForEach(displayMessages) { message in
                            MessageRowView(
                                message: message,
                                renderer: kernel.messageRendererManager?.renderer(for: message),
                                showRawMessage: $showRawMessage
                            )
                            .id(message.id)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }

                        // 底部锚点:通过它的几何位置判断 isAtBottom。
                        bottomAnchor
                    }
                    .padding(.vertical, 4)
                }
                .onPreferenceChange(MessageListBottomAnchorPositionKey.self) { bottomMaxY in
                    let viewMaxY = viewport.frame(in: .global).maxY
                    guard bottomMaxY.isFinite, viewMaxY.isFinite else { return }
                    // 底部锚点进入视口下方 48pt 容差范围 → 视为"在底部"。
                    isAtBottom = bottomMaxY <= viewMaxY + 48
                }
                .task(id: selectedConversationID) {
                    // 首屏数据就绪后,滚到最底部(无动画)。
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
                    // 尾部新消息/流式刷新:重新查最近一页,覆盖尾部;若用户在底部则滚到底。
                    Task {
                        let wasAtBottom = isAtBottom
                        await refreshTail()
                        if wasAtBottom {
                            // 等一帧让新内容布局后再滚动。
                            try? await Task.sleep(nanoseconds: 30_000_000)
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                }
                // 流式跟随滚动:store 的临时行变化时(kernel 自动转发 objectWillChange),
                // 若用户停在底部则跟随滚到底(无动画,避免高频 delta 抖动)。
                .onChange(of: kernel.messageStreaming?.currentStreamingRow?.content) { _ in
                    if isAtBottom {
                        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                    }
                }
            }
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
        .frame(height: 1)
        .id(Self.bottomAnchorID)
        .accessibilityHidden(true)
    }

    // MARK: - Data Loading

    /// 首屏:加载最近一页,并探测是否还有更早消息。
    private func loadFirstPage() async {
        guard let conversationID = selectedConversationID,
              let messageManager = kernel.messageManager else {
            messages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        let page = await readOffMain { messageManager.messagePage(for: conversationID, limit: pageSize, beforeMessageID: nil) } ?? []
        let hasEarlier = await readOffMain { messageManager.hasEarlierMessages(for: conversationID, beforeMessageID: page.first?.id) } ?? false
        // 切换会话期间用户可能又选了别的会话,丢弃过期结果。
        guard activeConversationID == conversationID else { return }
        messages = page
        hasEarlierMessages = hasEarlier
        isLoading = false
    }

    /// 向上翻页:加载更早一页并 prepend,保持滚动位置,触发窗口回收。
    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard !isLoadingEarlier,
              hasEarlierMessages,
              let conversationID = selectedConversationID,
              let messageManager = kernel.messageManager,
              let firstID = messages.first?.id else { return }

        isLoadingEarlier = true
        // 记住 prepend 前的"顶部第一条",prepend 后把它钉回视口顶部。
        let anchorID = firstID
        let earlier = await readOffMain { messageManager.messagePage(for: conversationID, limit: pageSize, beforeMessageID: firstID) } ?? []
        let stillHasEarlier = await readOffMain { messageManager.hasEarlierMessages(for: conversationID, beforeMessageID: earlier.first?.id) } ?? false
        guard activeConversationID == conversationID else {
            isLoadingEarlier = false
            return
        }
        guard !earlier.isEmpty else {
            isLoadingEarlier = false
            return
        }
        messages = earlier + messages
        hasEarlierMessages = stillHasEarlier
        isLoadingEarlier = false
        evictTailIfNeeded()

        // prepend 后,等一帧让新行布局,再把锚点行钉回视口顶部,避免视觉跳动。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            proxy.scrollTo(anchorID, anchor: .top)
        }
    }

    /// 尾部刷新:重新查最近一页,与当前尾部比对并更新;若用户在底部则滚到底。
    ///
    /// 只作用于真实落库消息(`messages`);流式临时行由 `MessageStreamingStore` 独立持有,
    /// 不参与此合并,故无需任何流式特例处理(摘出/挂回/去重)。
    private func refreshTail() async {
        guard let conversationID = selectedConversationID,
              let messageManager = kernel.messageManager else { return }

        let latestPage = await readOffMain { messageManager.messagePage(for: conversationID, limit: pageSize, beforeMessageID: nil) } ?? []
        guard activeConversationID == conversationID else { return }
        guard !latestPage.isEmpty else { return }

        // 合并:用最近一页覆盖尾部重叠区,保留头部更早的历史。
        // 找出当前 messages 中第一条属于 latestPage 的消息,从那里截断并拼接最新页。
        let latestIDs = Set(latestPage.map(\.id))
        if let firstOverlapIndex = messages.firstIndex(where: { latestIDs.contains($0.id) }) {
            messages = Array(messages[..<firstOverlapIndex]) + latestPage
        } else if messages.isEmpty {
            // 当前为空(首次异步到达),直接用最近一页。
            messages = latestPage
            hasEarlierMessages = await readOffMain { messageManager.hasEarlierMessages(for: conversationID, beforeMessageID: latestPage.first?.id) } ?? false
        } else {
            // 无重叠(用户在翻很早的历史,最近一页与当前完全不交):不强行覆盖,避免破坏位置。
            // 仍提示有最新消息;不滚动(用户在上方)。
            return
        }
    }

    // MARK: - Window Eviction

    /// 内存超阈值时丢弃尾部(较新、远离当前可视区的)消息。
    /// 仅在用户正在向上翻历史(即不在底部)时执行,避免裁掉正在流式的尾部。
    private func evictTailIfNeeded() {
        guard messages.count > maxRetainedCount, !isAtBottom else { return }
        let overflow = messages.count - maxRetainedCount
        messages.removeLast(overflow)
    }

    // MARK: - Scrolling

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard !messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    /// 在后台线程执行一段 nonisolated 读操作(返回 Sendable 结果),避免阻塞主线程。
    private func readOffMain<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T? {
        await Task.detached(priority: .userInitiated) { body() }.value
    }
}
