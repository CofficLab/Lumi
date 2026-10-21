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

    /// 运行时状态容器：底部标记、滚动协调器、底部几何控制器。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。
    ///   宿主（`ChatStackView.body` 里的 `item.makeView()`）每重绘一次就会
    ///   重新 `init` 本视图一次；`let` 持有的状态对象会被重建，新旧两个滚动
    ///   协调器会**同时驱动同一个 scroll view**（序号互不相识，`cancelPendingTasks()`
    ///   也 cancel 不掉对方），几何收敛永远不稳定，首屏遮罩就此永久挂起。
    ///   详见 `MessageListRuntime` 的类型注释。
    @StateObject private var runtime = MessageListRuntime()

    // MARK: - Services

    /// 内容完成一次更新后的滚动信号。触发器挂在底部锚点行上，确保新行已经
    /// 进入 List 布局后再执行 scrollTo，避免最后一行被底部输入框遮挡。
    @State private var scrollTick: Int = 0
    /// 发送新消息后，临时把最新回合定位在视口上方约四分之一处。
    @State private var usesPostSendPositioning = false
    @State private var viewportHeight: CGFloat = 0

    /// 首屏定位的就绪编排（含超时兜底），见 InitialPositionGate。
    ///
    /// - Important: 必须是 `@StateObject`，不能用 `let`。gate 是引用类型且
    ///   有生命周期；`let` 会在 View 每次 init 时新建实例，`isReady` 恒为
    ///   false，遮罩「正在加载消息…」将永久不消失。`@StateObject` 同时提供
    ///   跨重建的实例同一性与 `ObservableObject` 变更通知。
    @StateObject private var initialPositionGate = InitialPositionGate()

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
                .opacity(initialPositionGate.isReady ? 1 : 0)
                .allowsHitTesting(initialPositionGate.isReady)
            if messageListVM.isLoading || !initialPositionGate.isReady {
                MessageLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.opacity(0.6))
            }
        }
        .task {
            runtime.atBottomBox.value = true
            initialPositionGate.resetForLoadingStart()
            await messageListVM.activateCurrentConversation()
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
                        guard initialPositionGate.isReady else { return }
                        let conversationID = selectedConversationID
                        runtime.scrollCoordinator.scheduleScrollToBottomAfterLayout(
                            proxy: proxy,
                            messages: displayedHistoryMessages,
                            animated: false,
                            controller: runtime.bottomScrollController,
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
                    onChange: { runtime.atBottomBox.value = $0 },
                    controller: runtime.bottomScrollController,
                    onViewportHeightChange: updateViewportHeight
                )
            )
            .onChange(of: visibleRowIDs) { _, _ in
                // 发送后定位期间不跟随滚到底：此时 atBottomBox 是被"滚到占位
                // 底部"作伪成 true 的，跟随滚动会把最新内容贴到视口底部，抵消
                // 刚完成的"新回合停在视口上方"定位。定位结束后由
                // handleTurnLifecycleChange 恢复常规跟随。
                if runtime.atBottomBox.value, !usesPostSendPositioning {
                    scrollTick &+= 1
                }
                if !initialPositionGate.isReady, !messageListVM.isLoading {
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
                guard initialPositionGate.isReady,
                      runtime.atBottomBox.value,
                      !usesPostSendPositioning else { return }
                scrollTick &+= 1
            }
            .onChange(of: selectedConversationID) { _, _ in
                usesPostSendPositioning = false
                runtime.scrollCoordinator.cancelPendingTasks()
                initialPositionGate.resetForConversationSwitch()
            }
            .onChange(of: messageListVM.isLoading) { _, isLoading in
                if isLoading {
                    runtime.scrollCoordinator.cancelPendingTasks()
                    initialPositionGate.resetForLoadingStart()
                } else {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
            }
            .onAppear {
                if !messageListVM.isLoading {
                    prepareInitialPosition(proxy: proxy, messages: displayedHistoryMessages)
                }
                if runtime.atBottomBox.value {
                    scrollTick &+= 1
                }
            }
            .onDisappear {
                runtime.scrollCoordinator.cancelPendingTasks()
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
        let conversationID = selectedConversationID
        // 先把成员取到局部常量：闭包持有的就是同一批实例，
        // 不随视图重建而变（视图是 struct，被捕获的是副本）。
        let scrollCoordinator = runtime.scrollCoordinator
        let bottomScrollController = runtime.bottomScrollController
        let services = services
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
            stillRelevant: { [messageListVM, services] in
                // 期间会话被换掉、或又进入加载 → 本轮结果作废。
                // gate 内部另有 pendingConversationID 校验，这里补上
                // 真实选择状态与加载状态，双保险避免旧结果放行遮罩。
                conversationID == services.selectedConversationID && !messageListVM.isLoading
            }
        )
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
                        guard initialPositionGate.isReady,
                              runtime.atBottomBox.value,
                              !usesPostSendPositioning else { return }
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
                Text(pluginLocalization.string("Load earlier messages"))
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
        await runtime.scrollCoordinator.pinToAnchor(proxy: proxy, anchorID: anchorID)
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
        // 定位态结束：撤掉尾部留白并把视图对齐到真实内容底部。这里不再依赖
        // atBottomBox —— 定位期间用户停在"占位底部"，流式增长会让它翻成 false，
        // 若继续用该判定则回复结束后不会回到底部，用户会停在中间看不到收尾。
        scrollTick &+= 1
    }

    private func updateViewportHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        guard abs(viewportHeight - height) >= 0.5 else { return }
        viewportHeight = height
    }
}
