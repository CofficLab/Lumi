import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Message List V2 View (standard / 标准模式)
struct ListV2View: View, SuperLog {
    nonisolated static let logger = MessageListPlugin.logger
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = true

    let kernel: LumiKernel
    @StateObject private var viewModel: ListV2ViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近;用于决定新消息到达时是否自动滚到底部
    private let atBottomBox = AtBottomBox()

    /// 窗口是否在 live resize 中。为 true 时 LazyVStack 渲染轻量占位行而非富文本,
    /// 使 SwiftUI 在 resize 期间不再遍历昂贵的富文本子树 layout。
    /// 翻转触发 body 重建一次(有意为之),重建后子树已是轻量占位,后续帧零开销。
    @State private var isLiveResizing: Bool = false

    private let scrollCoordinator = MessageListScrollCoordinator()

    /// 内容就绪信号：historyRows 首尾消息 id 变化时 +1。
    @State private var scrollTick: Int = 0

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _viewModel = StateObject(wrappedValue: ListV2ViewModel(kernel: kernel))
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
        .background(LiveResizeDetector(isLiveResizing: $isLiveResizing))
        .task {
            if Self.verbose {
                Self.logger.info("\(self.t)首次出现,conversationID: \(viewModel.selectedConversationID?.uuidString ?? "nil")")
            }
            // 首次出现/容器切换重建:重置滚动位置,加载当前选中会话。
            atBottomBox.value = true
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
        .onLumiSelectedConversationDidChange { newID in
            if Self.verbose {
                Self.logger.info("\(self.t)选中会话切换：\(newID?.uuidString ?? "nil")")
            }
            atBottomBox.value = true
            Task { @MainActor in
                await viewModel.activate(conversationID: newID)
            }
        }
        .onLumiConversationsDidChange {
            if Self.verbose {
                Self.logger.info("\(self.t)会话设置变更,刷新行投影")
            }
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
                // Safe because the list is now pure database-driven: the
                // `ForEach` contains only stable, persisted ids. There is no
                // live streaming row swapping a transient id for its persisted
                // counterpart inside the same collection — that earlier swap
                // pattern was an AttributeGraph livelock source and has been
                // removed entirely (streaming content only lands here once it
                // is persisted at turn end).
                VStack(spacing: 0) {
                    historyRows(proxy: proxy)

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
                .padding(.top, 4)
                // 注入 V1「可折叠工具步骤组」的默认展开集合,供渲染层读取。
                .environment(\.lumiActiveToolGroupIDs, viewModel.activeStepGroupMessageIDs)
                .environment(\.lumiTurnActivitySummaries, viewModel.turnActivitySummaries)
            }
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
            // 兜底:锚点出现(内容从无到有)时也补一次,覆盖首屏/慢加载。
            .onAppear {
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            .onLumiMessagesDidChange { eventConversationID in
                guard MessageListNotificationFilter.shouldHandle(
                    eventConversationID: eventConversationID,
                    selectedConversationID: viewModel.selectedConversationID
                ) else { return }

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

    private var historyBoundary: HistoryBoundary {
        HistoryBoundary(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
    }

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await viewModel.loadEarlier(isAtBottom: atBottomBox.value) else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}

/// 消息列表首尾 id 对,用于 `onChange` 检测「首屏/新会话内容已加载」。
/// 元组无法遵循 `Equatable`,故用结构体承载。
private struct HistoryBoundary: Equatable {
    let first: UUID?
    let last: UUID?
}
