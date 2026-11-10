import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// Message List V4 View (ZCode 风格)
///
/// 与 V3（detailed）的差异：V4 把消息按**轮次**组织，而不是按行组织。
/// 一轮对话里的用户气泡、助手正文与工作历史被包进同一个 `ZCodeTurnView`，
/// 轮尾操作栏（整轮复制 + 时间）因此只出现一次，且挂在轮尾助手正文上。
///
/// ## 为什么仍然用 SwiftUI `List`
///
/// 与 V3 完全相同的理由：`LazyVStack` 在富文本长列表下会触发
/// AttributeGraph 活锁（主线程 100% CPU），普通 `VStack` 会 eager
/// materialize 全部行。macOS 上 `List` 底层是 `NSTableView`，有真正的
/// cell 复用。
///
/// - Important: 禁止把这里改成 `ScrollView + LazyVStack` 或 eager `VStack`。
struct ListV4View: View {
    let services: MessageListServices
    @ObservedObject private var developerModeState: DeveloperModeStateViewModel
    @ObservedObject private var viewModel: ListV4ViewModel

    @LumiTheme private var theme

    /// 运行时状态容器：底部标记、滚动协调器、底部几何控制器。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。
    ///   宿主每重绘一次就会重新 `init` 本视图一次；`let` 持有的状态对象会被
    ///   重建，新旧两个滚动协调器会同时驱动同一个 scroll view，首屏遮罩
    ///   永久挂起。详见 `MessageListRuntime` 的类型注释。
    @StateObject private var runtime = MessageListRuntime()

    /// 首屏定位的就绪编排（含超时兜底）。
    ///
    /// - Important: 必须是 `@StateObject`。gate 是引用类型且有生命周期；
    ///   `let` 会在 View 每次 init 时新建实例，遮罩「正在加载消息…」将永久不消失。
    @StateObject private var initialPositionGate = InitialPositionGate()

    /// 轮次投影缓存：只有历史变化才做 O(n) 重建。
    @StateObject private var projectionStore = ZCodeTurnProjectionStore()

    /// V4 滚动所有权 reducer：只有真实用户滚动才能改变 `following`。
    @StateObject private var scrollAnchor = ZCodeScrollAnchorBox()

    /// 内容就绪信号。
    @State private var scrollTick: Int = 0

    /// 聊天容器宽度（用于响应式列宽）。
    @State private var containerWidth: CGFloat = 0

    init(
        services: MessageListServices,
        developerModeState: DeveloperModeStateViewModel,
        viewModel: ListV4ViewModel
    ) {
        self.services = services
        _developerModeState = ObservedObject(wrappedValue: developerModeState)
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
                        ZCodeBackToBottomButton {
                            scrollAnchor.resumeFollowing()
                            runtime.atBottomBox.value = true
                            scrollTick &+= 1
                        }
                        .padding(.trailing, ZCodeBackToBottomStyle.trailingSpacing)
                        .padding(.bottom, ZCodeBackToBottomStyle.bottomSpacing)
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
                        .frame(height: 16)
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
                .accessibilityIdentifier(ZCodeAccessibilityIdentifiers.listContainer)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // 让 Markdown 代码块使用 HorizontalScrollView，不捕获垂直滚动
                .environment(\.preferOuterScroll, true)
                .background(
                    ScrollViewBottomTracker(
                        onChange: { runtime.atBottomBox.value = $0 },
                        controller: runtime.bottomScrollController,
                        // V4：额外上报滚动**来源**，让 reducer 能区分
                        // 真实用户滚动与程序化 / 布局滚动。
                        mode: .v4,
                        onScrollEvent: { source, snapshot in
                            handleScrollEvent(source: source, snapshot: snapshot)
                        },
                        // V4：用户已上滚离开底部时，文档变高**不得**把用户拽回去。
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

    // MARK: - Turns

    /// 处理一次带来源的滚动事件。
    ///
    /// - Important: 只有 `.user` 来源能改变 `following`；
    ///   程序化与布局事件只更新几何账目（由 reducer 自身保证）。
    private func handleScrollEvent(
        source: ZCodeScrollEventSource,
        snapshot: ScrollViewBottomController.Snapshot
    ) {
        let metrics = ZCodeScrollMetrics(
            userDirection: scrollAnchor.lastUserDirection,
            offsetY: snapshot.offsetY,
            visibleHeight: snapshot.visibleHeight,
            documentHeight: snapshot.documentHeight
        )
        scrollAnchor.handleScroll(metrics: metrics, source: source)
        // 「是否在底部」与 V4 的 following 保持一致，
        // 让已有的贴底逻辑（scrollTick）在离底后不再抢滚动。
        runtime.atBottomBox.value = scrollAnchor.anchor.following
    }

    /// 当前投影出的轮次。
    private var projection: ZCodeTurnProjection {
        projectionStore.snapshot(
            history: viewModel.historyRows,
            streaming: viewModel.streamingRow,
            activity: viewModel.activityMessage
        )
    }

    @ViewBuilder
    private var turnRows: some View {
        ForEach(projection.turns) { turn in
            ZCodeTurnView(
                services: services,
                developerModeState: developerModeState,
                turn: turn,
                verbosity: viewModel.verbosity,
                containerWidth: containerWidth
            )
            .id(turn.id)
            .plainMessageListRow(insets: EdgeInsets())
        }
    }

    /// 流式尾行已作为独立的一轮包含在 projection 里，无需重复渲染。
    @ViewBuilder
    private var streamingTurn: some View {
        EmptyView()
    }

    /// 活动行同理。
    @ViewBuilder
    private var activityTurn: some View {
        EmptyView()
    }

    /// 顶部「加载更早消息」：仅在还有更早消息时显示。
    @ViewBuilder
    private func loadEarlierButton(proxy: ScrollViewProxy) -> some View {
        if viewModel.hasEarlierMessages {
            Button {
                Task { await loadEarlier(proxy: proxy) }
            } label: {
                if viewModel.isLoadingEarlier {
                    ProgressView().controlSize(.small)
                } else {
                    Text(pluginLocalization.string("Load earlier messages"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .plainMessageListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await viewModel.loadEarlier() else { return }
        await runtime.scrollCoordinator.pinToAnchor(
            target: ProxyMessageListScrollingTarget(
                proxy: proxy,
                controller: runtime.bottomScrollController
            ),
            anchorID: anchorID
        )
    }

    // MARK: - 首屏

    private func prepareInitialPosition(
        proxy: ScrollViewProxy,
        messages: [ProviderMessage.Message]
    ) {
        let conversationID = viewModel.selectedConversationID
        let scrollCoordinator = runtime.scrollCoordinator
        let bottomScrollController = runtime.bottomScrollController
        initialPositionGate.request(
            conversationID: conversationID,
            settle: { [scrollCoordinator, bottomScrollController] in
                await scrollCoordinator.prepareInitialBottom(
                    target: ProxyMessageListScrollingTarget(
                        proxy: proxy,
                        controller: bottomScrollController
                    ),
                    messages: messages,
                    condition: { true }
                )
            },
            stillRelevant: { [viewModel] in
                conversationID == viewModel.selectedConversationID && !viewModel.isLoading
            }
        )
    }

    /// 消息列表首尾 id，用于 `onChange` 检测「首屏/新会话内容已加载」。
    private struct HistoryBoundaryV4: Equatable {
        let first: UUID?
        let last: UUID?
    }

    private var historyBoundary: HistoryBoundaryV4 {
        HistoryBoundaryV4(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
    }
}
