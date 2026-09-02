import Combine
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
    @StateObject private var viewModel: ListV3ViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近；用于决定新消息到达时是否自动滚到底部
    private let atBottomBox = AtBottomBox()

    private let scrollCoordinator = MessageListScrollCoordinator()

    /// 内容就绪信号：historyRows 首尾消息 id 变化时 +1。
    @State private var scrollTick: Int = 0

    /// 选中对话变化观察者令牌：视图消失时释放（自动注销）。
    @State private var selectedObserverToken: (any SelectedConversationObserverHandle)?

    init(services: MessageListServices) {
        self.services = services
        _viewModel = StateObject(wrappedValue: ListV3ViewModel(services: services))
    }

    var body: some View {
        ZStack {
            if viewModel.hasPersistedMessages {
                messageScrollView
            } else {
                MessageEmptyStateView(services: services)
            }
            if viewModel.isLoading {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        .task {
            // 首次出现/容器切换重建：重置滚动位置，加载当前选中会话。
            atBottomBox.value = true
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
        // 选中对话变化：callback 机制（替代旧版 `.lumiSelectedConversationDidChange` 通知）。
        // 视图消失时释放令牌自动注销，无需手动反注册。
        .onAppear {
            selectedObserverToken = services.addSelectedConversationObserver { newID in
                atBottomBox.value = true
                Task(priority: .userInitiated) { @MainActor in
                    await viewModel.activate(conversationID: newID)
                }
            }
        }
        .onDisappear {
            selectedObserverToken?.cancel()
            selectedObserverToken = nil
        }
        // 会话设置变化（verbosity 等）：订阅 ConversationManaging 窄播
        // （替代旧版 `.lumiConversationsDidChange` 通知）。
        .onReceive(services.conversationsChangesPublisher) { _ in
            viewModel.refreshConversationSettingsIfNeeded()
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            // List(NSTableView)自带 cell 复用：只有可见行被 materialize。
            //
            // 历史行（`ForEach`）只含稳定的落库 id。流式行（`streamingRow`）作为
            // 独立的、用进程级常量 `LumiStreamingRowID` 标识的尾行单独渲染 ——
            // 它与落库行的随机 UUID 永不冲突，落库时流式行消失 + 真实行出现被
            // SwiftUI 作为两次独立 diff 处理，无 id 交换、无闪烁。token 增长只
            // 让这一行的内容变化，不触发 `historyRows` 全量 rebuild（避免活锁）。
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
                        proxy.scrollTo(
                            MessageListScrollCoordinator.bottomAnchorID,
                            anchor: .bottom
                        )
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // 让 Markdown 代码块使用 HorizontalScrollView，不捕获垂直滚动
            .environment(\.preferOuterScroll, true)
            .background(
                ScrollViewBottomTracker(
                    onChange: { atBottomBox.value = $0 }
                )
            )
            .onChange(of: historyBoundary) { _, _ in
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            // 流式行出现（nil→非 nil）时跟随滚到底；内容增长期间沿用 atBottomBox
            // 判定（用户上滑则不跟随）。流式行用独立 id，此处按其 id 变化触发。
            .onChange(of: viewModel.streamingRow?.id) { _, _ in
                guard viewModel.streamingRow != nil, atBottomBox.value else { return }
                scrollTick &+= 1
            }
            // 兜底：锚点出现（内容从无到有）时也补一次，覆盖首屏/慢加载。
            .onAppear {
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            // 用户消息已经由 ViewModel 从内存事件直接应用；这里仅负责滚到底部，
            // 不再监听 objectWillChange 触发数据库尾部查询。
            .onChange(of: viewModel.latestUserMessageID) { _, newID in
                guard newID != nil else { return }
                atBottomBox.value = true
                scrollTick &+= 1
            }
        }
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
                    Text(LumiPluginLocalization.string("Load earlier messages"))
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
            MessageRowView(services: services, message: activity, verbosity: viewModel.verbosity)
                .id("conversation-activity")
                .plainMessageListRow()
        }
    }

    private var historyBoundary: HistoryBoundaryV3 {
        HistoryBoundaryV3(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
    }

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await viewModel.loadEarlier(isAtBottom: atBottomBox.value) else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}

/// 消息列表首尾 id 对，用于 `onChange` 检测「首屏/新会话内容已加载」。
/// 元组无法遵循 `Equatable`，故用结构体承载。
private struct HistoryBoundaryV3: Equatable {
    let first: UUID?
    let last: UUID?
}
