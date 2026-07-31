import LumiKernel
import LumiUI
import SwiftUI

/// Message List View
///
/// Displays the chat message list for the selected conversation.
///
/// 采用游标分页:首屏只加载最近一页(pageSize 条),向上滚动到顶部时可加载更早的一页,
/// 内存中最多保留 `maxRetainedCount` 条,超出则丢弃尾部(较新、远离可视区的)消息,
/// 使内存占用与消息总量无关。
///
/// **业务策略下沉到 `Services/`**:
/// - `MessagePaginationService` —— 首屏 / 向上翻页 / 尾部刷新 / 窗口回收 + 后台读切换。
/// - `MessageListRowBuilder` —— 拼接真实行 + 流式行 + 状态行为最终展示序列。
/// - `MessageListScrollCoordinator` —— 底部锚点判定 + 滚动(普通 / 跟随 / post-layout)。
///
/// 本 View 只负责:SwiftUI 渲染、生命周期挂载、`@State` 持有、调用 Service。
struct MessageListView: View {
    @ObservedObject var kernel: LumiKernel

    /// 精确订阅流式 store（窄播），绕开 kernel 的全局 objectWillChange 广播。
    /// 流式期间 store 每个 token 都更新;若经 kernel 广播会拖慢整个 app。
    @StateObject private var streamingBox = ObservableMessageStreamingBox()

    @LumiTheme private var theme

    /// 当前内存中的真实消息,按时间升序排列(最老在前、最新在后)。
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

    // MARK: - Services

    private let pagination = MessagePaginationService()
    private let rowBuilder = MessageListRowBuilder()
    private let scrollCoordinator = MessageListScrollCoordinator()

    // MARK: - Derived State

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    /// 当前会话的响应详细程度;未选择会话或读取失败时回退到默认值。
    /// 通过 `MessageRowView` 透传给 `LumiMessageRendererItem.render` 闭包，
    /// 渲染器可据此切换简洁/标准/详细外观。
    private var currentVerbosity: LumiResponseVerbosity {
        kernel.conversationManager?
            .verbosity(for: selectedConversationID) ?? .defaultVerbosity
    }

    /// 当前会话是否正在发送。
    private var isSending: Bool {
        kernel.messageSender?.isSending(for: selectedConversationID) ?? false
    }

    /// 真实消息 + 流式临时行 + 发送中状态行的合并列表(由 `MessageListRowBuilder` 产出)。
    private var displayMessages: [LumiChatMessage] {
        rowBuilder.build(
            persisted: messages,
            conversationID: selectedConversationID,
            sender: kernel.messageSender,
            streaming: streamingBox
        )
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
            // 绑定流式 store(box 精确订阅,绕开 kernel 广播)。幂等:重复绑定同实例为 no-op。
            streamingBox.bind(kernel.messageStreaming)
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
                                verbosity: currentVerbosity
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
                        messages: messages,
                        animated: false
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
                    // 尾部新消息/流式刷新:重新查最近一页,覆盖尾部;若用户在底部则滚到底。
                    Task {
                        let wasAtBottom = isAtBottom
                        await refreshTail()
                        if wasAtBottom {
                            await scrollCoordinator.scrollToBottomAfterLayout(
                                proxy: proxy,
                                messages: messages
                            )
                        }
                    }
                }
                // 流式跟随滚动:box 订阅的 store 临时行变化时,
                // 若用户停在底部则跟随滚到底(无动画,避免高频 delta 抖动)。
                .onChange(of: streamingBox.service?.currentStreamingRow?.content) { _ in
                    if isAtBottom {
                        proxy.scrollTo(MessageListScrollCoordinator.bottomAnchorID, anchor: .bottom)
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
        .id(MessageListScrollCoordinator.bottomAnchorID)
        .accessibilityHidden(true)
    }

    // MARK: - Data Loading (委托给 Services,仅剩生命周期/过期判定)

    /// 首屏:加载最近一页,并探测是否还有更早消息。
    /// 过期会话切换的结果丢弃逻辑保留在 View(因它持有 `activeConversationID`)。
    private func loadFirstPage() async {
        guard let conversationID = selectedConversationID else {
            messages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        let result = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: kernel.messageManager
        )
        // 切换会话期间用户可能又选了别的会话,丢弃过期结果。
        guard activeConversationID == conversationID else { return }
        messages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
        isLoading = false
    }

    /// 向上翻页:加载更早一页并 prepend,保持滚动位置,触发窗口回收。
    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let conversationID = selectedConversationID,
              !isLoadingEarlier,
              let currentFirstID = messages.first?.id else { return }
        isLoadingEarlier = true
        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            currentFirstID: currentFirstID,
            hasEarlier: hasEarlierMessages
        ) else {
            isLoadingEarlier = false
            return
        }
        guard activeConversationID == conversationID else {
            isLoadingEarlier = false
            return
        }
        messages = result.earlier + messages
        hasEarlierMessages = result.hasEarlierMessages
        messages = pagination.evictTailIfNeeded(messages: messages, isAtBottom: isAtBottom)
        isLoadingEarlier = false
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: result.anchorID)
    }

    /// 尾部刷新:重新查最近一页,与当前尾部比对并更新;若用户在底部则滚到底。
    ///
    /// 只作用于真实落库消息(`messages`);流式临时行由 `MessageStreamingStore` 独立持有,
    /// 不参与此合并,故无需任何流式特例处理(摘出/挂回/去重)。
    private func refreshTail() async {
        guard let conversationID = selectedConversationID else { return }
        guard let result = await pagination.refreshTail(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            current: messages
        ) else { return }
        guard activeConversationID == conversationID else { return }
        messages = result.merged
        if let hasEarlier = result.hasEarlierMessages {
            hasEarlierMessages = hasEarlier
        }
    }
}
