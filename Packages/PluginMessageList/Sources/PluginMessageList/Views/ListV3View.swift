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

    init(services: MessageListServices) {
        self.services = services
        _viewModel = StateObject(wrappedValue: ListV3ViewModel(services: services))
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
        .task {
            // 首次出现/容器切换重建：重置滚动位置，加载当前选中会话。
            atBottomBox.value = true
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
        .onReceive(NotificationCenter.default.publisher(for: LumiListNotifications.selectedConversationDidChange)) { notification in
            let newID = notification.lumiConversationID
            atBottomBox.value = true
            Task { @MainActor in
                await viewModel.activate(conversationID: newID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: LumiListNotifications.conversationsDidChange)) { _ in
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
            .onReceive(messageChangesPublisher) { _ in
                handleMessagesDidChange(proxy: proxy)
            }
        }
    }

    /// 落库消息变化的窄播（替代旧版 `.lumiMessagesDidChange` 通知）。
    /// `receive(on:)` 让回调在属性写入完成后异步执行。
    private var messageChangesPublisher: AnyPublisher<Void, Never> {
        guard let messages = services.messages else {
            return Empty().eraseToAnyPublisher()
        }
        return messages.objectWillChange
            .map { _ in () }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// 消息变化处理：合并刷新 + 按需滚动（与旧版 `onLumiMessagesDidChange` 行为一致）。
    private func handleMessagesDidChange(proxy: ScrollViewProxy) {
        guard MessageListNotificationFilter.shouldHandle(
            eventConversationID: nil,
            selectedConversationID: viewModel.selectedConversationID
        ) else { return }

        let targetConversationID = viewModel.selectedConversationID
        let wasAtBottom = atBottomBox.value
        // 记录刷新前最后一条用户消息 id，用于判定「用户本人刚发送了新消息」。
        let previousLastUserMessageID = viewModel.historyRows
            .last(where: { $0.role == .user })?.id
        Task {
            let didChange = await viewModel.refreshTail()
            guard didChange,
                  viewModel.selectedConversationID == targetConversationID else { return }

            // 用户本人发送：像常见聊天软件一样无条件滚到底，
            // 并把底部判定重置回 true（tracker 会随后按几何自校准）。
            let lastUserMessageID = viewModel.historyRows
                .last(where: { $0.role == .user })?.id
            let isOwnSend = lastUserMessageID != nil
                && lastUserMessageID != previousLastUserMessageID
            guard wasAtBottom || isOwnSend else { return }
            if isOwnSend { atBottomBox.value = true }

            // 不再用 `atBottomBox.value` 作为实时滚动条件：新行追加后首次
            // scrollTo 常落点偏上，tracker 可能把 atBottomBox 翻成 false，
            // 取消本应修正落点的 +100ms 重试。用事件时刻的一次性判定。
            await scrollCoordinator.scrollToBottomAfterLayout(
                proxy: proxy,
                messages: viewModel.historyRows,
                animated: false,
                condition: { true }
            )
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
