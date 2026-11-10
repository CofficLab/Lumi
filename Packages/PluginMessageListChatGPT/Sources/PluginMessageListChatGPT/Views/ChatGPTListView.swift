import CoreGraphics
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V5（ChatGPT 风格）消息列表视图。
///
/// 与 V1–V3 的差异：V5 把消息按**轮次**组织，而不是按行组织。
/// 一轮对话里的用户气泡、助手正文与工作历史被包进同一个 `ChatGPTTurnView`，
/// 轮尾操作因此只出现一次，且挂在轮尾助手正文上。
///
/// ## 滚动所有权
///
/// V5 的核心交互承诺是「**不抢阅读位置**」：
/// - 用户向上滚动后立即脱离跟随；
/// - 流式 delta、异步测高、reasoning/tool 折叠、窗口 resize
///   都**不得**把用户拉回底部；
/// - 用户回到底部 48pt 内或点击「回到底部」后恢复跟随。
///
/// 滚动所有权由 `ChatGPTScrollAnchor` reducer 独占决定：
/// 只有 `.user` 来源的滚动事件能改变 `following`，
/// 程序化滚动与布局变化只更新几何账目。
///
/// ## 为什么仍然用 SwiftUI `List`
///
/// 与其它档位相同的理由：`LazyVStack` 在富文本长列表下会触发
/// AttributeGraph 活锁（主线程 100% CPU），普通 `VStack` 会 eager
/// materialize 全部行。macOS 上 `List` 底层是 `NSTableView`，有真正的 cell 复用。
///
/// - Important: 禁止把这里改成 `ScrollView + LazyVStack` 或 eager `VStack`。
struct ChatGPTListView: View {
    let services: MessageListServices
    @ObservedObject private var viewModel: ChatGPTListViewModel

    @LumiTheme private var theme

    /// 运行时状态容器：底部标记、滚动协调器、底部几何控制器。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。
    ///   宿主每重绘一次就会重新 `init` 本视图一次；`let` 持有的状态对象会被
    ///   重建，新旧两个滚动协调器会同时驱动同一个 scroll view，
    ///   首屏遮罩永久挂起。
    @StateObject private var runtime = MessageListRuntime()

    /// 首屏定位的就绪编排（含超时兜底）。
    ///
    /// - Important: 必须是 `@StateObject`。gate 是引用类型且有生命周期；
    ///   `let` 会在 View 每次 init 时新建实例，遮罩「正在加载消息…」将永久不消失。
    @StateObject private var initialPositionGate = InitialPositionGate()

    /// V5 滚动所有权 reducer：只有真实用户滚动才能改变 `following`。
    @StateObject private var scrollAnchor = ChatGPTScrollAnchorBox()

    /// 轮次投影缓存：只有历史变化才做 O(n) 重建。
    @StateObject private var projectionStore = ChatGPTTurnProjectionStore()

    /// 内容就绪信号。
    @State private var scrollTick: Int = 0

    /// 聊天容器宽度（用于响应式列宽）。
    @State private var containerWidth: CGFloat = 0

    init(services: MessageListServices, viewModel: ChatGPTListViewModel) {
        self.services = services
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Important: GeometryReader 只用来读**聊天容器宽度**，
            // 不读取任何底部锚点 preference —— 偏好反馈会形成活锁。
            GeometryReader { proxy in
                messageScrollView
                    .onAppear { containerWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newValue in
                        containerWidth = newValue
                    }
            }
            .opacity(initialPositionGate.isReady ? 1 : 0)
            .allowsHitTesting(initialPositionGate.isReady)
            if !initialPositionGate.isReady {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
            // 「回到底部」按钮：只在脱离跟随且有内容时出现。
            if scrollAnchor.shouldShowBackToBottom(rowCount: projection.turns.count) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ChatGPTBackToBottomButton {
                            scrollAnchor.resumeFollowing()
                            runtime.atBottomBox.value = true
                            scrollTick &+= 1
                        }
                        .padding(.bottom, ChatGPTBackToBottomStyle.bottomSpacing)
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            runtime.atBottomBox.value = true
            initialPositionGate.resetForLoadingStart()
            projectionStore.reset()
            await viewModel.activateCurrentConversation()
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            // Important: 观察者必须待在 `.id()` 作用域**之外**，
            //   但仍要在 `ScrollViewReader` 闭包**之内**（它们要用 `proxy`）。
            //   `.id()` 会给被包裹的子树换一整套 identity，作用域内的 `onChange`
            //   会随子树一起被重建，基线值被重置为重建那一刻的值，
            //   于是「会话切换」这个变化本身永远不会被观察到。
            Group {
                List {
                    loadEarlierButton(proxy: proxy)
                    turnRows
                    streamingTurn
                    activityTurn

                    // 底部锚点行：纯占位 + 稳定 id（供 scrollTo 用），不报偏好。
                    // 是否在底部由 `ScrollViewBottomTracker` 观察 NSScrollView 判定。
                    Color.clear
                        .frame(height: ChatGPTConversationLayout.bottomAnchorSpacing)
                        .id(MessageListScrollCoordinator.bottomAnchorID)
                        .accessibilityHidden(true)
                        .plainMessageListRow(insets: EdgeInsets())
                        .onChange(of: scrollTick) { _ in
                            guard initialPositionGate.isReady else { return }
                            let conversationID = viewModel.selectedConversationID
                            runtime.scrollCoordinator.scheduleScrollToBottomAfterLayout(
                                target: ProxyMessageListScrollingTarget(
                                    proxy: proxy,
                                    controller: runtime.bottomScrollController
                                ),
                                messages: viewModel.historyRows,
                                animated: false,
                                condition: {
                                    conversationID == viewModel.selectedConversationID
                                }
                            )
                        }
                }
                .id(viewModel.selectedConversationID)
                .accessibilityIdentifier(ChatGPTAccessibilityIdentifiers.listContainer)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // 让 Markdown 代码块使用 HorizontalScrollView，不捕获垂直滚动
                .environment(\.preferOuterScroll, true)
                .background(
                    ScrollViewBottomTracker(
                        onChange: { runtime.atBottomBox.value = $0 },
                        controller: runtime.bottomScrollController,
                        // V5：上报滚动**来源**，让 reducer 能区分
                        // 真实用户滚动与程序化 / 布局滚动。
                        onScrollEvent: { source, snapshot in
                            handleScrollEvent(source: source, snapshot: snapshot)
                        },
                        // 用户已上滚离开底部时，文档变高**不得**把用户拽回去。
                        shouldAutoFollow: { scrollAnchor.anchor.following },
                        // 用户往回滚时立即解除跟随。
                        onUserScrollDirection: { direction in
                            scrollAnchor.handleUserScroll(direction: direction)
                            runtime.atBottomBox.value = scrollAnchor.anchor.following
                        }
                    )
                )
            }
            .onChange(of: historyBoundary) { _ in
                if runtime.atBottomBox.value {
                    scrollTick &+= 1
                }
                if !initialPositionGate.isReady, !viewModel.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: viewModel.historyRows)
                }
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                if isLoading {
                    runtime.scrollCoordinator.cancelPendingTasks()
                    initialPositionGate.resetForLoadingStart()
                } else {
                    prepareInitialPosition(proxy: proxy, messages: viewModel.historyRows)
                }
            }
            .onChange(of: viewModel.selectedConversationID) { _ in
                runtime.scrollCoordinator.cancelPendingTasks()
                initialPositionGate.resetForConversationSwitch()
                projectionStore.reset()
                // 切换会话重置滚动所有权：新会话默认跟随底部。
                scrollAnchor.resetFollowing()
            }
            .onChange(of: viewModel.streamingRow) { _ in
                guard viewModel.streamingRow != nil, runtime.atBottomBox.value else { return }
                scrollTick &+= 1
            }
            .onAppear {
                if !viewModel.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: viewModel.historyRows)
                }
                if runtime.atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            .onChange(of: viewModel.latestUserMessageID) { newID in
                guard newID != nil else { return }
                runtime.atBottomBox.value = true
                scrollTick &+= 1
            }
            .onDisappear {
                runtime.scrollCoordinator.cancelPendingTasks()
            }
        }
    }

    // MARK: - 滚动所有权

    /// 处理一次带来源的滚动事件。
    ///
    /// - Important: 只有 `.user` 来源能改变 `following`；
    ///   程序化与布局事件只更新几何账目（由 reducer 自身保证）。
    private func handleScrollEvent(
        source: ChatGPTScrollEventSource,
        snapshot: ScrollViewBottomController.Snapshot
    ) {
        let metrics = ChatGPTScrollMetrics(
            userDirection: scrollAnchor.lastUserDirection,
            offsetY: snapshot.offsetY,
            visibleHeight: snapshot.visibleHeight,
            documentHeight: snapshot.documentHeight
        )
        scrollAnchor.handleScroll(metrics: metrics, source: source)
        // 「是否在底部」与 following 保持一致，
        // 让贴底逻辑在离底后不再抢滚动。
        runtime.atBottomBox.value = scrollAnchor.anchor.following
    }

    // MARK: - Turns

    /// 当前投影出的轮次。
    private var projection: ChatGPTTurnProjection {
        projectionStore.snapshot(
            history: viewModel.historyRows,
            streaming: viewModel.streamingRow,
            activity: viewModel.activityMessage
        )
    }

    /// 历史部分的边界标识：只关心「历史行是否变化」。
    ///
    /// - Note: 用轮次 id 列表而不是消息数组本身 ——
    ///   消息内容变化可能不改变轮次边界，但**必须**触发一次投影重建，
    ///   否则复制文本会停留在旧内容上。
    private var historyBoundary: [String] {
        projection.historyTurnIDs
    }

    @ViewBuilder
    private var turnRows: some View {
        ForEach(projection.turns) { turn in
            ChatGPTTurnView(
                services: services,
                turn: turn,
                verbosity: viewModel.verbosity,
                containerWidth: containerWidth
            )
            .id(turn.id)
            .accessibilityIdentifier(ChatGPTAccessibilityIdentifiers.turn)
        }
    }

    @ViewBuilder
    private var streamingTurn: some View {
        if let streaming = viewModel.streamingRow {
            ChatGPTTurnView(
                services: services,
                turn: ChatGPTTurnProjector.project(
                    history: [],
                    streaming: streaming,
                    activity: nil
                ).turns[0],
                verbosity: viewModel.verbosity,
                containerWidth: containerWidth
            )
            .id("chatgpt-streaming-turn")
        }
    }

    @ViewBuilder
    private var activityTurn: some View {
        if let activity = viewModel.activityMessage,
           viewModel.streamingRow == nil {
            ChatGPTTurnView(
                services: services,
                turn: ChatGPTTurnProjector.project(
                    history: [],
                    streaming: nil,
                    activity: activity
                ).turns[0],
                verbosity: viewModel.verbosity,
                containerWidth: containerWidth
            )
            .id("chatgpt-activity-turn")
        }
    }

    // MARK: - 加载更早

    @ViewBuilder
    private func loadEarlierButton(proxy: ScrollViewProxy) -> some View {
        if viewModel.hasEarlierMessages {
            HStack {
                Spacer()
                if viewModel.isLoadingEarlier {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            // prepend 之后必须把原首条可见消息钉回视口顶部，
                            // 否则用户翻历史时阅读位置会突然跳走。
                            guard let anchorID = await viewModel.loadEarlier() else { return }
                            await runtime.scrollCoordinator.pinToAnchor(
                                target: ProxyMessageListScrollingTarget(
                                    proxy: proxy,
                                    controller: runtime.bottomScrollController
                                ),
                                anchorID: anchorID
                            )
                        }
                    } label: {
                        Text(pluginLocalization.string("加载更早的消息"))
                            .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.textSecondary)
                    .accessibilityIdentifier(ChatGPTAccessibilityIdentifiers.loadEarlierButton)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 首屏定位

    /// 请求首屏定位。
    private func prepareInitialPosition(
        proxy: ScrollViewProxy,
        messages: [Message]
    ) {
        let conversationID = viewModel.selectedConversationID
        initialPositionGate.request(
            conversationID: conversationID,
            settle: { [runtime] in
                await runtime.scrollCoordinator.prepareInitialBottom(
                    target: ProxyMessageListScrollingTarget(
                        proxy: proxy,
                        controller: runtime.bottomScrollController
                    ),
                    messages: messages,
                    condition: {
                        conversationID == viewModel.selectedConversationID
                    }
                )
            },
            stillRelevant: {
                conversationID == viewModel.selectedConversationID && !viewModel.isLoading
            }
        )
    }
}
