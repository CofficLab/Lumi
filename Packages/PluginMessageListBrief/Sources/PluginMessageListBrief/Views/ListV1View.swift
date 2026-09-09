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
    /// 发送新消息后，临时把最新回合定位在视口上方约四分之一处。
    @State private var usesPostSendPositioning = false
    @State private var viewportHeight: CGFloat = 0
    @State private var activeTurnHeight: CGFloat = 0
    @State private var isInitialPositionReady = false
    @State private var isPreparingInitialPosition = false

    init(
        services: MessageListServices,
        viewModel: ListV1ViewModel
    ) {
        self.services = services
        _turnViewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            messageScrollView
                .opacity(isInitialPositionReady ? 1 : 0)
                .allowsHitTesting(isInitialPositionReady)
            if turnViewModel.isLoading || !isInitialPositionReady {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        .task {
            atBottomBox.value = true
            isInitialPositionReady = false
            isPreparingInitialPosition = false
            await turnViewModel.activate(conversationID: selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            List {
                historyRows(proxy: proxy)

                if postSendTailReserve > 0 {
                    Color.clear
                        .frame(height: postSendTailReserve)
                        .accessibilityHidden(true)
                        .plainMessageListRow(insets: EdgeInsets())
                }

                Color.clear
                    .frame(height: 16)
                    .id(MessageListScrollCoordinator.bottomAnchorID)
                    .accessibilityHidden(true)
                    .plainMessageListRow(insets: EdgeInsets())
                    .onChange(of: scrollTick) { _, _ in
                        guard isInitialPositionReady else { return }
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
                    controller: bottomScrollController,
                    onViewportHeightChange: updateViewportHeight
                )
            )
            .onChange(of: visibleRowIDs) { _, _ in
                if atBottomBox.value {
                    scrollTick &+= 1
                }
                if !isInitialPositionReady, !turnViewModel.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
            }
            .onChange(of: displayedUserMessageIDs) { oldIDs, newIDs in
                handleUserMessageInsertion(oldIDs: oldIDs, newIDs: newIDs)
            }
            .onChange(of: turnViewModel.agentTurns) { _, items in
                handleTurnLifecycleChange(items)
            }
            .onPreferenceChange(ActiveTurnHeightPreferenceKey.self) { height in
                updateActiveTurnHeight(height)
            }
            .onChange(of: selectedConversationID) { _, _ in
                usesPostSendPositioning = false
                activeTurnHeight = 0
                scrollCoordinator.cancelPendingTasks()
                isInitialPositionReady = false
                isPreparingInitialPosition = false
            }
            .onChange(of: turnViewModel.isLoading) { _, isLoading in
                if isLoading {
                    scrollCoordinator.cancelPendingTasks()
                    isInitialPositionReady = false
                    isPreparingInitialPosition = false
                } else {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
            }
            .onAppear {
                if !turnViewModel.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
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

    private func prepareInitialPosition(
        proxy: ScrollViewProxy,
        messages: [ProviderMessage.Message]
    ) {
        guard !isInitialPositionReady, !isPreparingInitialPosition else { return }
        let conversationID = selectedConversationID
        isPreparingInitialPosition = true
        Task { @MainActor in
            let ready = await scrollCoordinator.prepareInitialBottom(
                proxy: proxy,
                messages: messages,
                controller: bottomScrollController,
                condition: {
                    conversationID == selectedConversationID && !turnViewModel.isLoading
                }
            )
            isPreparingInitialPosition = false
            if ready, conversationID == selectedConversationID, !turnViewModel.isLoading {
                isInitialPositionReady = true
            }
        }
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
                .background {
                    if item.acceptsLiveActivity {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ActiveTurnHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                }
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

    private var displayedUserMessageIDs: [UUID] {
        displayedHistoryMessages
            .filter { $0.role == .user }
            .map(\.id)
    }

    private var latestDisplayedUserMessageID: UUID? {
        displayedHistoryMessages
            .filter { $0.role == .user }
            .max(by: { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            })?
            .id
    }

    private var postSendTailReserve: CGFloat {
        guard usesPostSendPositioning else { return 0 }
        return MessageListSendPositioning.tailReserve(
            viewportHeight: viewportHeight,
            activeTurnHeight: activeTurnHeight
        )
    }

    private var verbosity: ResponseVerbosity {
        services.verbosity(for: selectedConversationID)
    }

    // MARK: - Pagination Trigger

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await turnViewModel.loadEarlier() else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }

    // MARK: - Post-send positioning

    private func handleUserMessageInsertion(oldIDs: [UUID], newIDs: [UUID]) {
        guard !turnViewModel.isLoading else { return }
        let insertedIDs = Set(newIDs).subtracting(oldIDs)
        guard !insertedIDs.isEmpty,
              let latestDisplayedUserMessageID,
              insertedIDs.contains(latestDisplayedUserMessageID) else { return }

        usesPostSendPositioning = true
        // A send should bring the new turn into view even if the user was
        // reading an older part of the conversation.
        scrollTick &+= 1
    }

    private func handleTurnLifecycleChange(_ items: [AgentTurnPresentationItem]) {
        guard usesPostSendPositioning,
              !items.contains(where: \.acceptsLiveActivity) else { return }

        usesPostSendPositioning = false
        activeTurnHeight = 0
        if atBottomBox.value {
            scrollTick &+= 1
        }
    }

    private func updateViewportHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        viewportHeight = height
    }

    private func updateActiveTurnHeight(_ height: CGFloat) {
        guard height.isFinite, height >= 0 else { return }
        activeTurnHeight = height
    }
}

private struct ActiveTurnHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
