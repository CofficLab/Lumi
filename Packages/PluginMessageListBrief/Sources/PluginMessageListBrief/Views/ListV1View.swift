import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// Message List V1 View (brief / 简洁模式)
///
/// 每个 AgentTurn 渲染成一组：触发该 turn 的用户消息 + 稳定的 turn 容器。
/// 运行中容器展示 status、思考、工具调用及最终回复（隐藏工具原始输出）；
/// turn 结束时动画折叠，只保留最终回复。历史终态 turn 首次加载时直接显示结果。
struct ListV1View: View {
    let services: MessageListServices
    @ObservedObject private var turnViewModel: ListV1ViewModel

    @LumiTheme private var theme

    /// 用户是否停在列表底部附近；用于决定新消息到达时是否自动滚到底部。
    private let atBottomBox = AtBottomBox()

    // MARK: - Services

    private let scrollCoordinator = MessageListScrollCoordinator()

    /// 内容完成一次更新后的滚动信号。触发器挂在底部锚点行上，确保新行已经
    /// 进入 List 布局后再执行 scrollTo，避免最后一行被底部输入框遮挡。
    @State private var scrollTick: Int = 0
    private let bottomScrollController = ScrollViewBottomController()

    init(
        services: MessageListServices,
        viewModel: ListV1ViewModel
    ) {
        self.services = services
        _turnViewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if turnViewModel.isLoading {
                MessageLoadingView()
            } else {
                messageScrollView
            }
        }
        .task {
            atBottomBox.value = true
            await turnViewModel.activate(conversationID: selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            List {
                historyRows(proxy: proxy)

                Color.clear
                    .frame(height: 16)
                    .id(MessageListScrollCoordinator.bottomAnchorID)
                    .accessibilityHidden(true)
                    .plainMessageListRow(insets: EdgeInsets())
                    .onChange(of: scrollTick) { _, _ in
                        scrollCoordinator.scheduleScrollToBottomAfterLayout(
                            proxy: proxy,
                            messages: displayedHistoryMessages,
                            animated: false,
                            controller: bottomScrollController,
                            condition: { true }
                        )
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Code blocks must keep only horizontal scrolling. Let the List
            // own vertical scrolling, matching V2/V3 behavior.
            .environment(\.preferOuterScroll, true)
            .background(
                ScrollViewBottomTracker(
                    onChange: { atBottomBox.value = $0 },
                    controller: bottomScrollController
                )
            )
            .onChange(of: visibleRowIDs) { _, _ in
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            .onAppear {
                if atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            .onDisappear {
                scrollCoordinator.cancelPendingTasks()
            }
        }
    }

    private var selectedConversationID: UUID? {
        services.selectedConversationID
    }

    @ViewBuilder
    private func historyRows(proxy: ScrollViewProxy) -> some View {
        if turnViewModel.hasEarlierTurns {
            loadEarlierButton(isLoading: turnViewModel.isLoadingEarlier) {
                Task { await loadEarlier(proxy: proxy) }
            }
            .plainMessageListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        ForEach(turnViewModel.rows) { row in
            switch row {
            case let .agentTurn(item):
                AgentTurnView(
                    services: services,
                    item: item,
                    verbosity: verbosity,
                    viewModel: turnViewModel.agentTurnViewModel(for: item)
                )
                .id(item.id)
                .plainMessageListRow()
            case let .timelineEvent(message):
                MessageRowView(
                    services: services,
                    message: message,
                    verbosity: verbosity
                )
                .id(message.id)
                .plainMessageListRow()
            }
        }
    }

    private func loadEarlierButton(
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Text(LumiPluginLocalization.string("Load earlier messages"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var displayedHistoryMessages: [ProviderMessage.Message] { turnViewModel.displayMessages }

    private var visibleRowIDs: [UUID] {
        displayedHistoryMessages.map(\.id)
    }

    private var verbosity: ResponseVerbosity {
        services.verbosity(for: selectedConversationID)
    }

    // MARK: - Pagination Trigger

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await turnViewModel.loadEarlier() else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }
}
