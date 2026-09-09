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
    private var messageObserver: MessageObserver?
    private var conversationStateObserver: ConversationStateObserver?
    private var selectedConversationObserver: SelectedConversationObserver?
    private var conversationStateViewModel: ConversationStateViewModel?
    private var developerModeObserver: DeveloperModeObserver?
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

        let services = MessageListServices(
            conversations: conversations.map(MessageListConversationCapabilityAdapter.init(conversations:)),
            developerMode: developerMode.map(MessageListDeveloperModeCapabilityAdapter.init(developerMode:)),
            messages: messages.map(MessageListMessageCapabilityAdapter.init(messages:)),
            rendering: rendering.map(MessageListRenderingCapabilityAdapter.init(rendering:)),
            toolManager: toolManager.map(MessageListToolManagerCapabilityAdapter.init(toolManager:)),
            agentTurn: agentTurn.map(MessageListAgentLoopCapabilityAdapter.init(agentTurn:)),
        )
        let viewModel = ListV1ViewModel(services: services)
        self.viewModel = viewModel
        let conversationStateViewModel = ConversationStateViewModel()
        self.conversationStateViewModel = conversationStateViewModel

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
                    viewModel: viewModel,
                    conversationStateViewModel: conversationStateViewModel
                ))
            }
        )
        self.verbosityObservation = verbosityObservation

        if let developerMode = services.developerMode {
            developerModeObserver = DeveloperModeObserver(
                developerMode: developerMode,
                viewModel: viewModel
            )
        }

        if let messages {
            messageObserver = MessageObserver(messages: messages, viewModel: viewModel)
        }
        if let conversationState {
            conversationStateObserver = ConversationStateObserver(
                state: conversationState,
                streaming: streaming,
                conversationID: conversations?.selectedConversationID,
                viewModel: conversationStateViewModel
            )
        }
        if let conversations {
            selectedConversationObserver = SelectedConversationObserver(
                conversations: conversations,
                viewModel: viewModel,
                conversationStateViewModel: conversationStateViewModel,
                conversationStateObserver: conversationStateObserver
            )
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        messageObserver?.cancel()
        messageObserver = nil
        conversationStateObserver?.cancel()
        conversationStateObserver = nil
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        conversationStateViewModel = nil
        developerModeObserver?.cancel()
        developerModeObserver = nil
        verbosityObservation?.cancel()
        verbosityObservation = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}
