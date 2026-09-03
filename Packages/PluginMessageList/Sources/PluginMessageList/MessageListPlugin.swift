import Combine
import os
import KernelCore
import KitSuperLog
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import ProviderPromptSuggestion
import ProviderProject
import ProviderToolbar
import ProviderToolManager
import SwiftUI

@MainActor
public final class MessageListPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list", category: "MessageList")

    public let id = "com.coffic.lumi.plugin.message-list"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list",
        name: "消息列表",
        description: "会话消息时间线：brief/standard/detailed 三种展示模式（V1/V2/V3）",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var viewModels: MessageListViewModels?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var conversationStateObserver: (any ConversationStateObserverHandle)?
    private var streamingObserver: (any MessageStreamingObserverHandle)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private var chatObserver: (any ChatSectionProvidingObserverHandle)?
    private var promptSuggestionsCancellable: AnyCancellable?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }
        let services = MessageListServices(
            conversations: kernel.resolveProvider((any ConversationManaging).self),
            conversationState: kernel.resolveProvider((any ConversationStateProviding).self),
            messages: kernel.resolveProvider((any MessageManaging).self),
            rendering: kernel.resolveProvider((any MessageRenderingProviding).self),
            streaming: kernel.resolveProvider((any MessageStreamingProviding).self),
            toolManager: kernel.resolveProvider((any ToolManagerProviding).self),
            agentTurn: kernel.resolveProvider((any AgentLoopProviding).self),
            promptSuggestions: kernel.resolveProvider((any PromptSuggestionProviding).self),
            promptSuggestionExecutor: kernel.resolveProvider((any PromptSuggestionExecuting).self),
            project: kernel.resolveProvider((any ProjectProviding).self),
            toolbar: kernel.resolveProvider((any ToolbarProviding).self),
            chat: chat,
        )
        let toolbarCoordinator = NoConversationSelectedToolbarCoordinator(
            project: services.project,
            toolbar: services.toolbar
        )
        let guideState = MessageListGuideState(
            context: chat.activeContext,
            project: services.project,
            toolbarCoordinator: toolbarCoordinator
        )
        let viewModels = MessageListViewModels(services: services, guide: guideState)
        self.viewModels = viewModels

        if let messages = services.messages {
            messageChangeObserver = messages.addMessageChangeObserver { [weak viewModels] change in
                viewModels?.handleMessageChange(change)
            }
        }
        if let conversationState = services.conversationState {
            conversationStateObserver = conversationState.addConversationStateObserver { [weak viewModels] event in
                viewModels?.handleConversationStateChange(event)
            }
        }
        if let streaming = services.streaming {
            streamingObserver = streaming.addMessageStreamingObserver { [weak viewModels] change in
                viewModels?.handleStreamingChange(change)
            }
        }
        if let conversations = services.conversations {
            selectedConversationObserver = conversations.addSelectedConversationObserver { [weak viewModels] conversationID in
                viewModels?.handleSelectedConversationChange(conversationID)
            }
            conversationObserver = conversations.addConversationObserver { [weak viewModels] _ in
                viewModels?.handleConversationChange()
            }
        }
        projectObserver = services.project?.addObserver { [weak viewModels, weak project = services.project] _ in
            viewModels?.guide.handleProjectChange(project)
        }
        chatObserver = chat.addObserver { [weak viewModels] event in
            guard case let .activeContextChanged(context) = event else { return }
            viewModels?.guide.handleContextChange(context)
        }
        promptSuggestionsCancellable = services.promptSuggestions?.changes.sink { [weak viewModels] _ in
            viewModels?.guide.handlePromptSuggestionsChange()
        }
        chat.addItems([ChatSectionItem(id: id, order: 100, fillsRemainingHeight: true) {
            ListView(services: services, viewModels: viewModels)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        messageChangeObserver?.cancel()
        messageChangeObserver = nil
        conversationStateObserver?.cancel()
        conversationStateObserver = nil
        streamingObserver?.cancel()
        streamingObserver = nil
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        conversationObserver?.cancel()
        conversationObserver = nil
        projectObserver?.cancel()
        projectObserver = nil
        chatObserver?.cancel()
        chatObserver = nil
        promptSuggestionsCancellable = nil
        viewModels = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: id)
    }

}
