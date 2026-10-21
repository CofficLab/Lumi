import Foundation
import LumiUI
import os
import ProviderConversation
import ProviderMessage
import LumiLoggingKit
import SwiftUI

/// Message List V2 View (standard / 标准模式)
struct ListV2View: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list", category: "ListV2View")
    nonisolated public static let emoji = "📄"
    nonisolated static let verbose = false

    let services: MessageListServices
    @ObservedObject private var developerModeState: DeveloperModeStateViewModel
    @ObservedObject private var viewModel: ListV2ViewModel

    @LumiTheme private var theme

    /// 运行时状态容器：底部标记、滚动协调器、底部几何控制器。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。
    ///   宿主（`ChatStackView.body` 里的 `item.makeView()`）每重绘一次就会
    ///   重新 `init` 本视图一次；`let` 持有的状态对象会被重建，状态全部清零。
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
        viewModel: ListV2ViewModel
    ) {
        self.services = services
        _developerModeState = ObservedObject(wrappedValue: developerModeState)
        _viewModel = ObservedObject(wrappedValue: viewModel)
        if Self.verbose {
            Self.logger.info("\(Self.t)ListV2View initialized: selectedConversation=\(services.selectedConversationID?.uuidString ?? "nil")")
        }
    }

    var body: some View {
        let _ = logContentDecision()
        ZStack {
            messageScrollView
                .id(viewModel.selectedConversationID)
                .opacity(initialPositionGate.isReady ? 1 : 0)
                .allowsHitTesting(initialPositionGate.isReady)
            if viewModel.isLoading || !initialPositionGate.isReady {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        .task {
            // 首次出现/容器切换重建：重置滚动位置，加载当前选中会话。
            runtime.atBottomBox.value = true
            initialPositionGate.resetForLoadingStart()
            if Self.verbose {
                Self.logger.debug("\(Self.t)activate conversation: \(viewModel.selectedConversationID?.uuidString ?? "nil")")
            }
            await viewModel.activateCurrentConversation()
        }
    }

    /// 记录内容决策：空态 vs 列表 vs loading。
    @discardableResult
    private func logContentDecision() -> String {
        guard Self.verbose else { return "" }
        let state = viewModel.isLoading ? "loading" : "list"
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
                        guard initialPositionGate.isReady else { return }
                        let conversationID = viewModel.selectedConversationID
                        // 新消息行可能还没有完成尺寸布局；立即 scrollTo 会把
                        // 锚点停在旧的内容底部，导致最后一行被输入框截断。
                        // 等布局完成后只保留最后一次滚动请求，避免多个
                        // scrollTo 同时驱动 macOS List 的行 materialize。
                        runtime.scrollCoordinator.scheduleScrollToBottomAfterLayout(
                            proxy: proxy,
                            messages: viewModel.historyRows,
                            animated: false,
                            controller: runtime.bottomScrollController,
                            condition: {
                                conversationID == viewModel.selectedConversationID
                            }
                        )
                    }
            }
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
            // 底部标记判定（用户上滑则不跟随）。不能只监听 id，因为流式
            // token 更新保持同一个行 id，但会持续改变行高。
            .onChange(of: viewModel.streamingRow) { _, _ in
                if Self.verbose, viewModel.streamingRow != nil {
                    Self.logger.debug("\(Self.t)streaming row appeared, following to bottom: atBottom=\(runtime.atBottomBox.value)")
                }
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
        // 先把成员取到局部常量：Swift 的捕获列表不能捕获成员路径，
        // 且这样闭包持有的就是同一批实例，不随视图重建而变。
        let scrollCoordinator = runtime.scrollCoordinator
        let bottomScrollController = runtime.bottomScrollController
        initialPositionGate.request(
            conversationID: conversationID,
            settle: { [scrollCoordinator, bottomScrollController] in
                await scrollCoordinator.prepareInitialBottom(
                    proxy: proxy,
                    messages: messages,
                    controller: bottomScrollController,
                    condition: { true }
                )
            },
            stillRelevant: { [viewModel] in
                // 期间会话被换掉、或又进入加载 → 本轮结果作废。
                // gate 内部另有 pendingConversationID 校验，这里补上
                // ViewModel 侧的真实选择状态，双保险避免旧结果放行遮罩。
                conversationID == viewModel.selectedConversationID && !viewModel.isLoading
            }
        )
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
                    Text(pluginLocalization.string("Load earlier messages"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .plainMessageListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .accessibilityIdentifier(ListV2Accessibility.loadEarlierButton)
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

    /// 流式尾行：LLM 回复期间逐字增长的临时行。仅在 thinking/generating 阶段由
    /// viewmodel 暴露。用进程级常量 `LumiStreamingRowID` 作为稳定 id，落库行用
    /// 随机 UUID，两者永不冲突；落库后 streamingRow 变 nil，真实行经 tail refresh
    /// 出现在历史行末尾，SwiftUI 自然完成"流式行消失 + 真实行出现"的替换。
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

    private var historyBoundary: HistoryBoundary {
        HistoryBoundary(first: viewModel.historyRows.first?.id, last: viewModel.historyRows.last?.id)
    }

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await viewModel.loadEarlier() else { return }
        if Self.verbose {
            Self.logger.debug("\(Self.t)loaded earlier messages, anchor=\(anchorID.uuidString)")
        }
        await runtime.scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}

/// 消息列表首尾 id 对，用于 `onChange` 检测「首屏/新会话内容已加载」。
/// 元组无法遵循 `Equatable`，故用结构体承载。
private struct HistoryBoundary: Equatable {
    let first: UUID?
    let last: UUID?
}

/// V2 列表的可访问性标识符。
///
/// - Important: UI 测试 target 无法 import 插件模块，因此常量在此定义、
///   在 UI 测试侧复述。改动必须两边同步。
enum ListV2Accessibility {
    /// 顶部「加载更早消息」按钮。
    ///
    /// 之所以用标识符而不是文案定位：按钮固定在 `List` 首行，首屏停在底部时
    /// 它处于视口外（AX 帧为 `0×0`），文案查询会命中消息正文里的同名文本，
    /// 点击落在错误的元素上。标识符则唯一指向这一个按钮。
    static let loadEarlierButton = "lumi.message-list.v2.load-earlier"
}
