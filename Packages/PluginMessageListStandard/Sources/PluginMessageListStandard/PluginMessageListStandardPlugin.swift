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

/// 标准（V2 / standard）消息列表插件。
@MainActor
public final class PluginMessageListStandardPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list.standard", category: "MessageListStandard")

    public let id = "com.coffic.lumi.plugin.message-list.standard"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.standard",
        name: "消息列表（标准）",
        description: "V2 标准模式消息列表",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var viewModel: ListV2ViewModel?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var conversationStateObserver: (any ConversationStateObserverHandle)?
    private var streamingObserver: (any MessageStreamingObserverHandle)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private var chatObserver: (any ChatSectionProvidingObserverHandle)?
    private var promptSuggestionsCancellable: AnyCancellable?
    private var verbosityObservation: VerbosityObservationBox?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let conversationState = kernel.resolveProvider((any ConversationStateProviding).self)
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
        let toolbarCoordinator = NoConversationSelectedToolbarCoordinator(
            project: services.project,
            toolbar: services.toolbar
        )
        let guideState = MessageListGuideState(
            context: chat.activeContext,
            project: services.project,
            toolbarCoordinator: toolbarCoordinator
        )
        let viewModel = ListV2ViewModel(services: services)
        self.viewModel = viewModel

        let verbosityObservation = VerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: id,
            expectedVerbosity: .standard,
            makeView: { [weak viewModel, weak guideState, services] in
                guard let viewModel, let guideState else { return AnyView(EmptyView()) }
                return AnyView(ListV2View(
                    services: services,
                    viewModel: viewModel,
                    guideState: guideState
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
        projectObserver = project?.addObserver { [weak guideState, projectCapability = services.project] _ in
            guideState?.handleProjectChange(projectCapability)
        }
        chatObserver = chat.addObserver { [weak guideState] event in
            guard case let .activeContextChanged(context) = event else { return }
            guideState?.handleContextChange(context)
        }
        promptSuggestionsCancellable = promptSuggestions?.changes.sink { [weak guideState] _ in
            guideState?.handlePromptSuggestionsChange()
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
        projectObserver?.cancel()
        projectObserver = nil
        chatObserver?.cancel()
        chatObserver = nil
        promptSuggestionsCancellable = nil
        verbosityObservation?.cancel()
        verbosityObservation = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}