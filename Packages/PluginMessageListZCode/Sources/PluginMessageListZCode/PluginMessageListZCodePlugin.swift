import os
import KernelCore
import LumiLoggingKit
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

/// ZCode（V4）消息列表插件。
///
/// 与 V1–V3 一样是**独立 Package**（`PluginMessageListZCode`）：
/// 独立的插件 ID、独立的 observer、独立的 `ListV4ViewModel` 实例、
/// 独立的 shutdown。不与其它消息列表包共享任何可变单例。
///
/// - Important: 本包**不依赖**任何其它消息列表包（插件不得依赖插件）。
///   `ListV4ViewModel`、分页、消息快照、流式事件、工具组合、
///   `List` cell 复用、初始定位与滚动协调底座都在本包内**各自实现一份**。
///
///   代价是 V3 与 V4 存在两份近似的基础设施实现；
///   收益是各档位可以独立演进、独立发布，且 V3 的行为完全不受 V4 影响。
@MainActor
public final class PluginMessageListZCodePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list.zcode", category: "MessageListZCode")

    public let id = "com.coffic.lumi.plugin.message-list.zcode"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.zcode",
        name: "消息列表（ZCode）",
        description: "V4 ZCode 风格消息列表",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var viewModel: ListV4ViewModel?
    private var developerModeObserver: DeveloperModeStateObserver?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var conversationStateObserver: (any ConversationStateObserverHandle)?
    private var streamingObserver: (any MessageStreamingObserverHandle)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?
    private var verbosityObservation: ZCodeVerbosityObservationBox?
    /// UI 测试夹具的 seed 句柄（仅 DEBUG 下存在）。
    private var uiTestingSeedHandle: (any ConversationObserverHandle)?

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
        // - Important: 创建**自己的** `ListV4ViewModel`，不共享 V3 的可变实例。
        //   `streamingDisplayEnabled` 保持生产默认值 false。
        let viewModel = ListV4ViewModel(services: services)
        self.viewModel = viewModel

        let verbosityObservation = ZCodeVerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: id,
            expectedVerbosity: .zcode,
            makeView: { [weak viewModel, services] in
                guard let viewModel else { return AnyView(EmptyView()) }
                return AnyView(ListV4View(
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

        // - Important: 整段（含 seed 调用与句柄赋值）必须在 `#if DEBUG` 内，
        //   否则 Release 下会引用只在 DEBUG 定义的类型而编译失败。
        #if DEBUG
        Self.logger.info("onBoot：V4 夹具启用=\(MessageListZCodeUITestingSupport.isEnabled)")
        if MessageListZCodeUITestingSupport.isEnabled, let conversations, let messages {
            uiTestingSeedHandle = MessageListZCodeUITestingSupport.seed(
                conversations: conversations,
                messages: messages,
                agentLoop: agentTurn
            )
        }
        #endif
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
        uiTestingSeedHandle?.cancel()
        uiTestingSeedHandle = nil
        developerModeObserver?.cancel()
        developerModeObserver = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}
