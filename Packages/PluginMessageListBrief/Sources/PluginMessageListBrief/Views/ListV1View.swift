import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// Message List V1 View (brief / 简洁模式)
///
/// 每个 AgentTurn 渲染成一组：触发该 turn 的用户消息 + 稳定的 turn 容器。
/// 每个 AgentTurn 展示用户消息、思考/工具过程及最终回复（隐藏工具原始输出）；
/// 当前对话状态由消息列表尾部的 ConversationStateView 独立展示。
struct ListV1View: View {
    let services: MessageListServices
    @ObservedObject private var messageListVM: ConversationMessageListVM
    @ObservedObject private var stateVM: ConversationStateVM

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
    @State private var isInitialPositionReady = false
    @State private var isPreparingInitialPosition = false

    init(
        services: MessageListServices,
        messageListVM: ConversationMessageListVM,
        stateVM: ConversationStateVM
    ) {
        self.services = services
        _messageListVM = ObservedObject(wrappedValue: messageListVM)
        _stateVM = ObservedObject(wrappedValue: stateVM)
    }

    var body: some View {
        ZStack {
            messageScrollView
                .id(selectedConversationID)
                .opacity(isInitialPositionReady ? 1 : 0)
                .allowsHitTesting(isInitialPositionReady)
            if messageListVM.isLoading || !isInitialPositionReady {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        .task {
            atBottomBox.value = true
            isInitialPositionReady = false
            isPreparingInitialPosition = false
            await messageListVM.activate(conversationID: selectedConversationID)
        }
    }

    // MARK: - Scroll View

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            List {
                historyRows(proxy: proxy)

                if stateVM.activity != nil {
                    ConversationStateView(stateVM: stateVM)
                        .plainMessageListRow()
                }

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
                        let conversationID = selectedConversationID
                        scrollCoordinator.scheduleScrollToBottomAfterLayout(
                            proxy: proxy,
                            messages: displayedHistoryMessages,
                            animated: false,
                            controller: bottomScrollController,
                            condition: {
                                conversationID == selectedConversationID
                            }
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
                if !isInitialPositionReady, !messageListVM.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
            }
            .onChange(of: displayedUserMessageIDs) { oldIDs, newIDs in
                handleUserMessageInsertion(oldIDs: oldIDs, newIDs: newIDs)
            }
            .onChange(of: messageListVM.agentTurns) { _, items in
                handleTurnLifecycleChange(items)
            }
            .onChange(of: stateVM.activity) { _, _ in
                guard isInitialPositionReady, atBottomBox.value else { return }
                scrollTick &+= 1
            }
            .onChange(of: selectedConversationID) { _, _ in
                usesPostSendPositioning = false
                scrollCoordinator.cancelPendingTasks()
                isInitialPositionReady = false
                isPreparingInitialPosition = false
            }
            .onChange(of: messageListVM.isLoading) { _, isLoading in
                if isLoading {
                    scrollCoordinator.cancelPendingTasks()
                    isInitialPositionReady = false
                    isPreparingInitialPosition = false
                } else {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
            }
            .onAppear {
                if !messageListVM.isLoading {
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
                    conversationID == selectedConversationID && !messageListVM.isLoading
                }
            )
            isPreparingInitialPosition = false
            if ready, conversationID == selectedConversationID, !messageListVM.isLoading {
                isInitialPositionReady = true
            }
        }
    }

    @ViewBuilder
    private func historyRows(proxy: ScrollViewProxy) -> some View {
        if messageListVM.hasEarlierTurns {
            loadEarlierButton(isLoading: messageListVM.isLoadingEarlier) {
                Task { await loadEarlier(proxy: proxy) }
            }
            .plainMessageListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        ForEach(messageListVM.rows) { row in
            switch row {
            case let .agentTurn(item):
                AgentTurnView(
                    services: services,
                    item: item,
                    verbosity: verbosity,
                    isDeveloperModeEnabled: messageListVM.isDeveloperModeEnabled,
                    turnVM: messageListVM.agentTurnVM(for: item),
                    onDynamicContentChange: {
                        guard isInitialPositionReady, atBottomBox.value else { return }
                        scrollTick &+= 1
                    }
                )
                .id(item.id)
                .plainMessageListRow()
            case let .timelineEvent(message):
                MessageRowView(
                    services: services,
                    message: message,
                    verbosity: verbosity,
                    isDeveloperModeEnabled: messageListVM.isDeveloperModeEnabled
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

    private var displayedHistoryMessages: [ProviderMessage.Message] { messageListVM.displayMessages }

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
        // Do not measure a live List row with GeometryReader + PreferenceKey.
        // Its height changes on every streamed token and feeding that value
        // back into List creates a layout feedback loop. A stable reserve
        // still places a newly sent turn near the top of the viewport; normal
        // bottom scrolling takes over once the turn finishes.
        return MessageListSendPositioning.conservativeTailReserve(
            viewportHeight: viewportHeight
        )
    }

    private var verbosity: ResponseVerbosity {
        services.verbosity(for: selectedConversationID)
    }

    // MARK: - Pagination Trigger

    private func loadEarlier(proxy: ScrollViewProxy) async {
        guard let anchorID = await messageListVM.loadEarlier() else { return }
        await scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
    }

    // MARK: - Post-send positioning

    private func handleUserMessageInsertion(oldIDs: [UUID], newIDs: [UUID]) {
        guard !messageListVM.isLoading else { return }
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
        if atBottomBox.value {
            scrollTick &+= 1
        }
    }

    private func updateViewportHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        guard abs(viewportHeight - height) >= 0.5 else { return }
        viewportHeight = height
    }
}
