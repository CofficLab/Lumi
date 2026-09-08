import Combine
import KernelCore
import KitSuperLog
import LumiUI
import os
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderProject
import ProviderPromptSuggestion
import ProviderToolbar
import SwiftUI

/// 独立的消息列表空态插件。
///
/// 它不依赖任何一个详细程度消息列表插件；通过 ChatSection 的互斥内容组，
/// 在未选中会话或当前会话没有消息时独立接管消息列表槽位。
@MainActor
public final class PluginMessageListEmptyPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-list.empty",
        category: "MessageListEmpty"
    )

    public let id = "com.coffic.lumi.plugin.message-list.empty"
    public let order = 81

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.empty",
        name: "消息列表（空态）",
        description: "无选中会话或无消息时的聊天空态",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var chat: (any ChatSectionProviding)?
    private var conversations: (any ConversationManaging)?
    private var messages: (any MessageManaging)?
    private var services: MessageListEmptyServices?
    private var guideState: MessageListGuideState?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private var chatObserver: (any ChatSectionProvidingObserverHandle)?
    private var promptSuggestionsCancellable: AnyCancellable?
    private var isRegistered = false

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }

        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let messages = kernel.resolveProvider((any MessageManaging).self)
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let promptSuggestions = kernel.resolveProvider((any PromptSuggestionProviding).self)
        let promptSuggestionExecutor = kernel.resolveProvider((any PromptSuggestionExecuting).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let services = MessageListEmptyServices(
            project: project,
            promptSuggestions: promptSuggestions,
            promptSuggestionExecutor: promptSuggestionExecutor
        )
        let toolbarCoordinator = NoConversationSelectedToolbarCoordinator(
            project: project,
            toolbar: toolbar
        )
        let guideState = MessageListGuideState(
            context: chat.activeContext,
            project: project,
            toolbarCoordinator: toolbarCoordinator
        )

        self.chat = chat
        self.conversations = conversations
        self.messages = messages
        self.services = services
        self.guideState = guideState

        selectedConversationObserver = conversations?.addSelectedConversationObserver { [weak self] conversationID in
            self?.updateSelection(conversationID)
            self?.reevaluateRegistration()
        }
        messageChangeObserver = messages?.addMessageChangeObserver { [weak self] change in
            self?.handleMessageChange(change)
        }
        projectObserver = project?.addObserver { [weak guideState, project] _ in
            guideState?.handleProjectChange(project)
        }
        chatObserver = chat.addObserver { [weak guideState] event in
            guard case let .activeContextChanged(context) = event else { return }
            guideState?.handleContextChange(context)
        }
        promptSuggestionsCancellable = promptSuggestions?.changes.sink { [weak guideState] _ in
            guideState?.handlePromptSuggestionsChange()
        }

        updateSelection(conversations?.selectedConversationID)
        reevaluateRegistration()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        messageChangeObserver?.cancel()
        messageChangeObserver = nil
        projectObserver?.cancel()
        projectObserver = nil
        chatObserver?.cancel()
        chatObserver = nil
        promptSuggestionsCancellable = nil

        if isRegistered {
            chat?.removeItem(id: id)
            isRegistered = false
        }
        guideState?.toolbarCoordinator.deactivate()
        guideState = nil
        services = nil
        messages = nil
        conversations = nil
        chat = nil
    }

    private func updateSelection(_ conversationID: UUID?) {
        guideState?.handleSelectionChange(conversationID)
    }

    private func handleMessageChange(_ change: MessageChange) {
        guard let selectedID = conversations?.selectedConversationID else {
            reevaluateRegistration()
            return
        }
        let changedID: UUID?
        switch change {
        case let .inserted(_, conversationID), let .persisted(_, conversationID),
             let .updated(conversationID), let .deleted(_, conversationID),
             let .cleared(conversationID):
            changedID = conversationID
        }
        guard changedID == selectedID else { return }
        reevaluateRegistration()
    }

    private func hasMessages(in conversationID: UUID) -> Bool {
        guard let messages else { return false }
        return !messages.messagePage(
            for: conversationID,
            limit: 1,
            beforeMessageID: nil,
            includesToolMessages: false
        ).isEmpty
    }

    private func reevaluateRegistration() {
        guard let chat else { return }
        let selectedID = conversations?.selectedConversationID
        updateSelection(selectedID)
        let shouldShow: Bool
        if let selectedID {
            shouldShow = !hasMessages(in: selectedID)
        } else {
            shouldShow = true
        }

        if shouldShow, !isRegistered {
            let services = services
            chat.addItems([
                ChatSectionItem(
                    id: id,
                    order: order,
                    exclusiveGroup: "message-list",
                    fillsRemainingHeight: true
                ) { [weak guideState] in
                    guard let services, let guideState else { return AnyView(EmptyView()) }
                    return AnyView(MessageListEmptyContentView(services: services, guideState: guideState))
                }
            ])
            isRegistered = true
        } else if !shouldShow, isRegistered {
            chat.removeItem(id: id)
            isRegistered = false
        }
    }
}

@MainActor
private struct MessageListEmptyContentView: View {
    let services: MessageListEmptyServices
    @ObservedObject var guideState: MessageListGuideState

    var body: some View {
        if guideState.selectedConversationID == nil {
            return AnyView(NoConversationSelectedView(services: services, guideState: guideState))
        }
        return AnyView(MessageEmptyStateView(services: services, guideState: guideState))
    }
}
