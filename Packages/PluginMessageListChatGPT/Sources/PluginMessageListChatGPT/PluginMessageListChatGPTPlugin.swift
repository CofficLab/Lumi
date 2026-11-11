import os
import KernelCore
import LumiLoggingKit
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import SwiftUI

/// V5（ChatGPT）消息列表插件。
///
/// 与 V1–V4 一样是**独立 Package**（`PluginMessageListChatGPT`）：
/// 独立的插件 ID、独立的 observer、独立的 `ChatGPTListViewModel` 实例、
/// 独立的 shutdown。不与其它消息列表包共享任何可变单例。
///
/// - Important: 本包**不依赖**任何其它消息列表包（插件不得依赖插件）。
///   `ChatGPTListViewModel`、分页、轮次投影、流式事件、工具组合、
///   `List` cell 复用、初始定位与滚动协调底座都在本包内**各自实现一份**。
@MainActor
public final class PluginMessageListChatGPTPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-list.chatgpt",
        category: "MessageListChatGPT"
    )

    public let id = "com.coffic.lumi.plugin.message-list.chatgpt"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.chatgpt",
        name: "消息列表（ChatGPT）",
        description: "V5 ChatGPT 风格消息列表",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var verbosityObservation: ChatGPTVerbosityObservationBox?
    /// V5 自己的视图模型实例；不与其它档位共享。
    private var viewModel: ChatGPTListViewModel?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var conversationStateObserver: (any ConversationStateObserverHandle)?
    private var streamingObserver: (any MessageStreamingObserverHandle)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?
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
        let messages = kernel.resolveProvider((any MessageManaging).self)
        let rendering = kernel.resolveProvider((any MessageRenderingProviding).self)
        let streaming = kernel.resolveProvider((any MessageStreamingProviding).self)
        let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)

        // 组装层把 Provider 收窄成插件的最小能力协议。
        let services = MessageListServices(
            conversations: conversations.map(MessageListConversationCapabilityAdapter.init(conversations:)),
            conversationState: conversationState.map(MessageListConversationStateCapabilityAdapter.init(conversationState:)),
            messages: messages.map(MessageListMessageCapabilityAdapter.init(messages:)),
            rendering: rendering.map(MessageListRenderingCapabilityAdapter.init(rendering:)),
            streaming: streaming.map(MessageListStreamingCapabilityAdapter.init(streaming:)),
            chat: MessageListChatSectionCapabilityAdapter(chat: chat)
        )
        // - Important: 创建**自己的** `ChatGPTListViewModel`，不共享其它档位的可变实例。
        //
        //   V5 是**唯一**开启真实流式的档位（ADR-4）：流式尾行让助手回复
        //   逐字显现，且逐帧合并更新。其它档位的默认 `false` 保持不变。
        let viewModel = ChatGPTListViewModel(
            services: services,
            streamingDisplayEnabled: true
        )
        self.viewModel = viewModel

        verbosityObservation = ChatGPTVerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: id,
            order: order,
            expectedVerbosity: .chatGPT,
            makeView: { [weak viewModel, services] in
                guard let viewModel else { return AnyView(EmptyView()) }
                return AnyView(
                    ChatGPTListView(
                        services: services,
                        viewModel: viewModel
                    )
                )
            }
        )

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
        Self.logger.info("onBoot：V5 夹具启用=\(MessageListChatGPTUITestingSupport.isEnabled)")
        if MessageListChatGPTUITestingSupport.isEnabled, let conversations, let messages {
            uiTestingSeedHandle = MessageListChatGPTUITestingSupport.seed(
                conversations: conversations,
                messages: messages,
                agentLoop: agentLoop
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
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}
