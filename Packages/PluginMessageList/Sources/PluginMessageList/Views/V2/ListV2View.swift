import Combine
import Foundation
import LumiUI
import os
import ProviderConversation
import ProviderMessage
import KitSuperLog
import SwiftUI

/// Message List V2 View (standard / 标准模式)
struct ListV2View: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list", category: "ListV2View")
    nonisolated public static let emoji = "📄"
    nonisolated static let verbose = false

    let services: MessageListServices
    @StateObject private var viewModel: ListV2ViewModel

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
        _viewModel = StateObject(wrappedValue: ListV2ViewModel(services: services))
        if Self.verbose {
            Self.logger.info("\(Self.t)ListV2View initialized: selectedConversation=\(services.selectedConversationID?.uuidString ?? "nil")")
        }
    }

    var body: some View {
        let _ = logContentDecision()
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
            if Self.verbose {
                Self.logger.debug("\(Self.t)activate conversation: \(viewModel.selectedConversationID?.uuidString ?? "nil")")
            }
            await viewModel.activate(conversationID: viewModel.selectedConversationID)
        }
        // 选中对话变化：callback 机制（替代旧版 `.lumiSelectedConversationDidChange` 通知）。
        // 视图消失时释放令牌自动注销，无需手动反注册。
        .onAppear {
            if Self.verbose {
                Self.logger.debug("\(Self.t)onAppear: registering selected conversation observer")
            }
            selectedObserverToken = services.addSelectedConversationObserver { newID in
                if Self.verbose {
                    Self.logger.debug("\(Self.t)selected conversation changed: \(newID?.uuidString ?? "nil")")
                }
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
            if Self.verbose {
                Self.logger.debug("\(Self.t)conversation settings changed, refreshing")
            }
            viewModel.refreshConversationSettingsIfNeeded()
        }
    }

    /// 记录内容决策：空态 vs 列表 vs loading。
    @discardableResult
    private func logContentDecision() -> String {
        guard Self.verbose else { return "" }
        let state = viewModel.hasPersistedMessages ? "list" : (viewModel.isLoading ? "loading" : "empty")
        let message = "\(Self.t)content decision: \(state), historyRows=\(viewModel.historyRows.count), isLoading=\(viewModel.isLoading)"
        Self.logger.debug("\(message)")
        return message
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
                if Self.verbose, viewModel.streamingRow != nil {
                    Self.logger.debug("\(Self.t)streaming row appeared, following to bottom: atBottom=\(atBottomBox.value)")
                }
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

    /// Stable historical rows. The live streaming tail is rendered separately
    /// so token updates do not rebuild this collection.
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

    /// 流式尾行：LLM 回复期间逐字增长的临时行。仅在 thinking/generating 阶段由
    /// viewmodel 暴露。用进程级常量 `LumiStreamingRowID` 作为稳定 id，落库行用
    /// 随机 UUID，两者永不冲突；落库后 streamingRow 变 nil，真实行经 tail refresh
    /// 出现在历史行末尾，SwiftUI 自然完成"流式行消失 + 真实行出现"的替换。
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

    private var historyBoundary: HistoryBoundary {
        HistoryBoundary(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
    }

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await viewModel.loadEarlier(isAtBottom: atBottomBox.value) else { return }
        if Self.verbose {
            Self.logger.debug("\(Self.t)loaded earlier messages, anchor=\(anchorID.uuidString)")
        }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}

/// 消息列表首尾 id 对，用于 `onChange` 检测「首屏/新会话内容已加载」。
/// 元组无法遵循 `Equatable`，故用结构体承载。
private struct HistoryBoundary: Equatable {
    let first: UUID?
    let last: UUID?
}
