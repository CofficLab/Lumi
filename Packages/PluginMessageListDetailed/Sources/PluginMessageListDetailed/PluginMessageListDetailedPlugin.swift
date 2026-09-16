import os
import KernelCore
import KitSuperLog
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import ProviderPromptSuggestion
import ProviderProject
import ProviderToolbar
import ProviderToolManager
import SwiftUI

/// 详细（V3 / detailed）消息列表插件。
@MainActor
public final class PluginMessageListDetailedPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list.detailed", category: "MessageListDetailed")

    public let id = "com.coffic.lumi.plugin.message-list.detailed"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.detailed",
        name: "消息列表（详细）",
        description: "V3 详细模式消息列表",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var viewModel: ListV3ViewModel?
    private var developerModeObserver: DeveloperModeStateObserver?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var conversationStateObserver: (any ConversationStateObserverHandle)?
    private var streamingObserver: (any MessageStreamingObserverHandle)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?
    private var verbosityObservation: VerbosityObservationBox?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let conversationState = kernel.resolveProvider((any ConversationStateProviding).self)
        let developerMode = kernel.resolveProvider((any DeveloperModeProviding).self)
        let developerModeState = DeveloperModeStateViewModel()
        let developerModeObserver = DeveloperModeStateObserver(
            provider: developerMode,
            viewModel: developerModeState
        )
        self.developerModeObserver = developerModeObserver
        let messages = kernel.resolveProvider((any MessageManaging).self)
        let rendering = kernel.resolveProvider((any MessageRenderingProviding).self)
        let streaming = kernel.resolveProvider((any MessageStreamingProviding).self)
        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        let agentTurn = kernel.resolveProvider((any AgentLoopProviding).self)
        let promptSuggestions = kernel.resolveProvider((any PromptSuggestionProviding).self)
        let promptSuggestionExecutor = kernel.resolveProvider((any PromptSuggestionExecuting).self)
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)

        let services = MessageListServices(
            conversations: conversations.map(MessageListConversationCapabilityAdapter.init(conversations:)),
            conversationState: conversationState.map(MessageListConversationStateCapabilityAdapter.init(conversationState:)),
            developerModeState: developerModeState,
            messages: messages.map(MessageListMessageCapabilityAdapter.init(messages:)),
            rendering: rendering.map(MessageListRenderingCapabilityAdapter.init(rendering:)),
            streaming: streaming.map(MessageListStreamingCapabilityAdapter.init(streaming:)),
            toolManager: toolManager.map(MessageListToolManagerCapabilityAdapter.init(toolManager:)),
            agentTurn: agentTurn.map(MessageListAgentLoopCapabilityAdapter.init(agentTurn:)),
            promptSuggestions: promptSuggestions.map(MessageListPromptSuggestionCapabilityAdapter.init(promptSuggestions:)),
            promptSuggestionExecutor: promptSuggestionExecutor.map(MessageListPromptSuggestionExecutorCapabilityAdapter.init(executor:)),
            project: project.map(MessageListProjectCapabilityAdapter.init(project:)),
            toolbar: toolbar.map(MessageListToolbarCapabilityAdapter.init(toolbar:)),
            chat: MessageListChatSectionCapabilityAdapter(chat: chat),
        )
        let viewModel = ListV3ViewModel(services: services)
        self.viewModel = viewModel

        let verbosityObservation = VerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: id,
            expectedVerbosity: .detailed,
            makeView: { [weak viewModel, services] in
                guard let viewModel else { return AnyView(EmptyView()) }
                return AnyView(ListV3View(
                    services: services,
                    developerModeState: developerModeState,
                    viewModel: viewModel
                ))
            }
        )
        self.verbosityObservation = verbosityObservation

        if let messages {
            messageChangeObserver = messages.addMessageChangeObserver { [weak viewModel] change in
                viewModel?.handleMessageChange(change)
            }
        }
        if let conversationState {
            conversationStateObserver = conversationState.addConversationStateObserver { [weak viewModel] event in
                viewModel?.handleConversationStateChange(event)
            }
        }
        if let streaming {
            streamingObserver = streaming.addMessageStreamingObserver { [weak viewModel] change in
                viewModel?.handleStreamingChange(change)
            }
        }
        if let conversations {
            selectedConversationObserver = conversations.addSelectedConversationObserver { [weak viewModel] conversationID in
                viewModel?.handleSelectedConversationChange(conversationID)
            }
            conversationObserver = conversations.addConversationObserver { [weak viewModel] _ in
                viewModel?.refreshConversationSettingsIfNeeded()
            }
        }
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
        verbosityObservation?.cancel()
        verbosityObservation = nil
        developerModeObserver?.cancel()
        developerModeObserver = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}
