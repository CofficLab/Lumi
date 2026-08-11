import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Message List V2 View (standard / 标准模式)
struct ListV2View: View, SuperLog {
    nonisolated static let logger = MessageListPlugin.logger
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = false

    let kernel: LumiKernel
    @StateObject private var viewModel: ListV2ViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近;用于决定新消息到达时是否自动滚到底部
    private let atBottomBox = AtBottomBox()

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
            // List(NSTableView)自带 cell 复用:只有可见行被 materialize。
            //
            // 历史行(`ForEach`)只含稳定的落库 id。流式行(`streamingRow`)作为
            // 独立的、用进程级常量 `LumiStreamingRowID` 标识的尾行单独渲染 ——
            // 它与落库行的随机 UUID 永不冲突,落库时流式行消失 + 真实行出现被
            // SwiftUI 作为两次独立 diff 处理,无 id 交换、无闪烁。token 增长只
            // 让这一行的内容变化,不触发 `historyRows` 全量 rebuild(避免活锁)。
            List {
                historyRows(proxy: proxy)
                streamingRowView

                // 底部锚点行:纯占位 + 稳定 id(供 scrollTo 用),不报偏好。
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
            // 注入 V1「可折叠工具步骤组」的默认展开集合,供渲染层读取。
            .environment(\.lumiActiveToolGroupIDs, viewModel.activeStepGroupMessageIDs)
            .environment(\.lumiTurnActivitySummaries, viewModel.turnActivitySummaries)
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
            // 流式行出现(nil→非 nil)时跟随滚到底;内容增长期间沿用 atBottomBox
            // 判定(用户上滑则不跟随)。流式行用独立 id,此处按其 id 变化触发。
            .onChange(of: viewModel.streamingRow?.id) { _, _ in
                guard viewModel.streamingRow != nil, atBottomBox.value else { return }
                scrollTick &+= 1
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
                // 记录刷新前最后一条用户消息 id,用于判定「用户本人刚发送了新消息」。
                let previousLastUserMessageID = viewModel.historyRows
                    .last(where: { $0.role == .user })?.id
                Task {
                    let didChange = await viewModel.refreshTail()
                    guard didChange,
                          viewModel.selectedConversationID == targetConversationID else { return }

                    // 用户本人发送:像常见聊天软件一样无条件滚到底,
                    // 并把底部判定重置回 true(tracker 会随后按几何自校准)。
                    let lastUserMessageID = viewModel.historyRows
                        .last(where: { $0.role == .user })?.id
                    let isOwnSend = lastUserMessageID != nil
                        && lastUserMessageID != previousLastUserMessageID
                    guard wasAtBottom || isOwnSend else { return }
                    if isOwnSend { atBottomBox.value = true }

                    // 注意:这里不再用 `atBottomBox.value` 作为实时滚动条件。
                    // 原因:新行追加后首次 scrollTo 常落点偏上,此时内容底沿
                    // 超出视口 > 离开阈值会让 tracker 把 atBottomBox 翻成 false,
                    // 从而取消本应修正落点的 +100ms 重试,导致列表停在半路 ——
                    // 这正是「有时不滚到底部」的根因。这里改用事件时刻的
                    // wasAtBottom / isOwnSend 做一次性判定,让重试能正常完成。
                    await scrollCoordinator.scrollToBottomAfterLayout(
                        proxy: proxy,
                        messages: viewModel.historyRows,
                        animated: false,
                        condition: { true }
                    )
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
            .plainMessageListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        ForEach(viewModel.historyRows) { message in
            MessageRowView(
                kernel: kernel,
                message: message,
                verbosity: viewModel.verbosity
            )
            .id(message.id)
            .plainMessageListRow()
        }
    }

    /// 流式尾行:LLM 回复期间逐字增长的临时行。仅在 thinking/generating 阶段由
    /// viewmodel 暴露。用进程级常量 `LumiStreamingRowID` 作为稳定 id,落库行用
    /// 随机 UUID,两者永不冲突;落库后 streamingRow 变 nil,真实行经 tail refresh
    /// 出现在历史行末尾,SwiftUI 自然完成"流式行消失 + 真实行出现"的替换。
    @ViewBuilder
    private var streamingRowView: some View {
        if let streaming = viewModel.streamingRow {
            MessageRowView(
                kernel: kernel,
                message: streaming,
                verbosity: viewModel.verbosity
            )
            .id(LumiStreamingRowID)
            .plainMessageListRow()
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
