import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// Message List V3 View (detailed / 详细模式)
///
/// 与 V2（standard）的差异：V3 **显示思考内容**（`reasoningContent`），V2 不显示。
/// 思考内容显示逻辑在此基础上增量加入（当前与 V2 行为一致，保留独立类型）。
///
/// ## 为什么用 SwiftUI `List` 而不是 ScrollView + LazyVStack
///
/// V2 的教训：`LazyVStack` 在富文本长列表下反复触发 AttributeGraph 活锁
/// （主线程 100% CPU 卡死），而普通 `VStack` 会 eager materialize 全部行，
/// 滚动明显卡顿。macOS 上 `List` 底层是 `NSTableView`，有真正的 cell 复用：
/// 懒加载但不经过 LazyStack 那套尺寸协商，天然避开已踩过的活锁。
struct ListV3View: View {
    let services: MessageListServices
    @ObservedObject private var developerModeState: DeveloperModeStateViewModel
    @ObservedObject private var viewModel: ListV3ViewModel

    @LumiTheme private var theme

    /// 运行时状态容器：底部标记、滚动协调器、底部几何控制器。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。
    ///   宿主（`ChatStackView.body` 里的 `item.makeView()`）每重绘一次就会
    ///   重新 `init` 本视图一次；`let` 持有的状态对象会被重建，新旧两个滚动
    ///   协调器会**同时驱动同一个 scroll view**（序号互不相识，`cancelPendingTasks()`
    ///   也 cancel 不掉对方），几何收敛永远不稳定，首屏遮罩就此永久挂起。
    ///   详见 `MessageListRuntime` 的类型注释。
    @StateObject private var runtime = MessageListRuntime()

    /// 内容就绪信号：historyRows 首尾消息 id 变化时 +1。
    @State private var scrollTick: Int = 0

    /// 首屏定位的就绪编排（含超时兜底），见 InitialPositionGate。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。gate 是引用类型且
    ///   有生命周期；`let` 会在 View 每次 init 时新建实例，`isReady` 恒为
    ///   false，遮罩「正在加载消息…」将永久不消失。`@StateObject` 同时提供
    ///   跨重建的实例同一性与 `ObservableObject` 变更通知。
    @StateObject private var initialPositionGate = InitialPositionGate()

    init(
        services: MessageListServices,
        developerModeState: DeveloperModeStateViewModel,
        viewModel: ListV3ViewModel
    ) {
        self.services = services
        _developerModeState = ObservedObject(wrappedValue: developerModeState)
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            messageScrollView
                .opacity(initialPositionGate.isReady ? 1 : 0)
                .allowsHitTesting(initialPositionGate.isReady)
            // Important: 遮罩的显示条件**只**看 gate。
            //   原先是 `isLoading || !gate.isReady`：`isLoading` 是一个可能停在
            //   true 不再回落的布尔（激活被跳过、加载卡住……），一旦它卡住，
            //   遮罩就再没有任何东西能把它撤掉 —— 用户界面上就是「正在加载消息…」
            //   永不消失。现在遮罩的寿命由 gate 的**预算兜底**唯一决定：
            //   挂起后最多一个预算，无论收敛有没有被启动、有没有成功。
            if !initialPositionGate.isReady {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        .task {
            // 首次出现/容器切换重建：重置滚动位置，加载当前选中会话。
            runtime.atBottomBox.value = true
            initialPositionGate.resetForLoadingStart()
            await viewModel.activateCurrentConversation()
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            // Important: 观察者必须待在 `.id()` 作用域**之外**，但仍要在
            //   `ScrollViewReader` 闭包**之内**（它们要用 `proxy`）。
            //
            //   `.id()` 会给被包裹的子树换一整套 identity：作用域内的 `onChange`
            //   会随子树一起被重建，基线值被重置为**重建那一刻**的值。于是
            //   「会话切换」这个变化本身永远不会被 `onChange` 观察到（基线已经是
            //   新值），`resetForConversationSwitch()` 形同死代码；`onChange(isLoading)`
            //   同理会在切换时丢掉「加载开始」那一次。
            //
            //   把 `.id()` 收窄到 List 本身（只重置行状态与滚动位置），观察者挂在
            //   包裹它的 Group 上：切换时它们仍在、基线仍在，事件不再丢失。
            Group {
                List {
                    historyRows(proxy: proxy)
                    streamingRowView
                    activityRowView

                    // 底部锚点行：纯占位 + 稳定 id（供 scrollTo 用），不报偏好。
                    // 是否在底部由 `ScrollViewBottomTracker` 观察 NSScrollView 判定。
                    Color.clear
                        .frame(height: 16)
                        .id(MessageListScrollCoordinator.bottomAnchorID)
                        .accessibilityHidden(true)
                        .plainMessageListRow(insets: EdgeInsets())
                        .onChange(of: scrollTick) { _, _ in
                            guard initialPositionGate.isReady else { return }
                            let conversationID = viewModel.selectedConversationID
                            // 新消息行可能还没有完成尺寸布局；立即 scrollTo 会把
                            // 锚点停在旧的内容底部，导致最后一行被输入框截断。
                            // 等布局完成后只保留最后一次滚动请求，避免多个
                            // scrollTo 同时驱动 macOS List 的行 materialize。
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
                    // 会话切换时重建 List：行状态与滚动位置回到初始。
                    // 放在 List 之后的所有修饰（尤其是底部追踪器）都在这个作用域内，
                    // 会随 List 一起重建，重新绑定到新的 NSScrollView。
                    .id(viewModel.selectedConversationID)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // 让 Markdown 代码块使用 HorizontalScrollView，不捕获垂直滚动
                .environment(\.preferOuterScroll, true)
                .background(
                    ScrollViewBottomTracker(
                        onChange: { runtime.atBottomBox.value = $0 },
                        controller: runtime.bottomScrollController
                    )
                )
            }
            .onChange(of: historyBoundary) { _, _ in
                if runtime.atBottomBox.value {
                    scrollTick &+= 1
                }
                if !initialPositionGate.isReady, !viewModel.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: viewModel.historyRows)
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    runtime.scrollCoordinator.cancelPendingTasks()
                    initialPositionGate.resetForLoadingStart()
                } else {
                    prepareInitialPosition(proxy: proxy, messages: viewModel.historyRows)
                }
            }
            .onChange(of: viewModel.selectedConversationID) { _, _ in
                runtime.scrollCoordinator.cancelPendingTasks()
                initialPositionGate.resetForConversationSwitch()
            }
            // 流式行出现或内容增长时跟随滚到底；内容增长期间沿用
            // atBottomBox 判定（用户上滑则不跟随）。不能只监听 id，因为流式
            // token 更新保持同一个行 id，但会持续改变行高。
            .onChange(of: viewModel.streamingRow) { _, _ in
                guard viewModel.streamingRow != nil, runtime.atBottomBox.value else { return }
                scrollTick &+= 1
            }
            // 兜底：锚点出现（内容从无到有）时也补一次，覆盖首屏/慢加载。
            .onAppear {
                if !viewModel.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: viewModel.historyRows)
                }
                if runtime.atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            // 用户消息已经由插件转发的类型化事件直接应用；这里仅负责滚到底部。
            .onChange(of: viewModel.latestUserMessageID) { _, newID in
                guard newID != nil else { return }
                runtime.atBottomBox.value = true
                scrollTick &+= 1
            }
            .onDisappear {
                runtime.scrollCoordinator.cancelPendingTasks()
            }
        }
    }

    private func prepareInitialPosition(
        proxy: ScrollViewProxy,
        messages: [ProviderMessage.Message]
    ) {
        let conversationID = viewModel.selectedConversationID
        // 先把成员取到局部常量：闭包持有的就是同一批实例，
        // 不随视图重建而变（视图是 struct，被捕获的是副本）。
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
                // 期间会话被换掉、或又进入加载 → 本轮结果作废。
                // gate 内部另有 pendingConversationID 校验，这里补上
                // 真实选择状态与加载状态，双保险避免旧结果放行遮罩。
                conversationID == viewModel.selectedConversationID && !viewModel.isLoading
            }
        )
    }

    /// Stable historical rows. Pure database-driven; rebuilt only when the
    /// persisted window changes.
    @ViewBuilder
    private func historyRows(proxy: ScrollViewProxy) -> some View {
        // 顶部"加载更早消息"：仅在还有更早消息时显示。
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

        ForEach(viewModel.historyRows) { message in
            MessageRowView(
                services: services,
                developerModeState: developerModeState,
                message: message,
                verbosity: viewModel.verbosity
            )
            .id(message.id)
            .plainMessageListRow()
        }
    }

    /// 流式尾行：LLM 回复期间逐字增长的临时行。V3（detailed）额外显示思考内容
    /// （`reasoningContent`），thinking 阶段流式行的 reasoningContent 增长，
    /// `MarkdownBlockRenderer` 自动命中 streamingSlot 增量解析。id 语义同 V2。
    @ViewBuilder
    private var streamingRowView: some View {
        if let streaming = viewModel.streamingRow {
            MessageRowView(
                services: services,
                developerModeState: developerModeState,
                message: streaming,
                verbosity: viewModel.verbosity
            )
            .id(LumiStreamingRowID)
            .plainMessageListRow()
        }
    }

    @ViewBuilder
    private var activityRowView: some View {
        if let activity = viewModel.activityMessage, viewModel.streamingRow == nil {
            MessageRowView(services: services, developerModeState: developerModeState, message: activity, verbosity: viewModel.verbosity)
                .id("conversation-activity")
                .plainMessageListRow()
        }
    }

    private var historyBoundary: HistoryBoundaryV3 {
        HistoryBoundaryV3(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
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
}

/// 消息列表首尾 id 对，用于 `onChange` 检测「首屏/新会话内容已加载」。
/// 元组无法遵循 `Equatable`，故用结构体承载。
private struct HistoryBoundaryV3: Equatable {
    let first: UUID?
    let last: UUID?
}
