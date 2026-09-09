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

/// 简洁（V1 / brief）消息列表插件。
///
/// 只在自己对应的详细程度（.brief）下展示 ChatSectionItem；详细程度变化时
/// 自动添加/移除自己，不依赖其他兄弟包。
@MainActor
public final class PluginMessageListBriefPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list.brief", category: "MessageListBrief")

    public let id = "com.coffic.lumi.plugin.message-list.brief"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.brief",
        name: "消息列表（简洁）",
        description: "V1 简洁模式消息列表",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var viewModel: ListV1ViewModel?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var streamingObserver: (any MessageStreamingObserverHandle)?
    private var conversationStateObserver: (any ConversationStateObserverHandle)?
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
            developerMode: developerMode,
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
        let viewModel = ListV1ViewModel(services: services)
        self.viewModel = viewModel

        // 观察详细程度变化，仅 .brief 时注册自己
        let verbosityObservation = VerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: id,
            expectedVerbosity: .brief,
            makeView: { [weak viewModel, services] in
                guard let viewModel else { return AnyView(EmptyView()) }
                return AnyView(ListV1View(
                    services: services,
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
        if let streaming {
            streamingObserver = streaming.addMessageStreamingObserver { [weak viewModel] change in
                viewModel?.handleStreamingChange(change)
            }
        }
        if let conversationState {
            conversationStateObserver = conversationState.addConversationStateObserver { [weak viewModel] change in
                viewModel?.handleConversationStateChange(change)
            }
        }
        if let conversations {
            selectedConversationObserver = conversations.addSelectedConversationObserver { [weak viewModel] conversationID in
                viewModel?.handleSelectedConversationChange(conversationID)
            }
            conversationObserver = conversations.addConversationObserver { _ in
                // V1 不需要 verbosity 变化时刷新（verbosity 变化由 observation box 处理
                // 显示/隐藏，因此不在这里处理）
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        messageChangeObserver?.cancel()
        messageChangeObserver = nil
        streamingObserver?.cancel()
        streamingObserver = nil
        conversationStateObserver?.cancel()
        conversationStateObserver = nil
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        conversationObserver?.cancel()
        conversationObserver = nil
        verbosityObservation?.cancel()
        verbosityObservation = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}
