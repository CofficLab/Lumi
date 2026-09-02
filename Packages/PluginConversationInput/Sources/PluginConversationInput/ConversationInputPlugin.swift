import KernelCore
import LumiUI
import os
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderConversationInput
import ProviderMessageSender
import ProviderPerformanceMetrics
import KitSuperLog
import SwiftUI

/// Conversation Input Plugin
@MainActor
public final class ConversationInputPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-input", category: "ConversationInput")

    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let order = 83
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-input",
        name: "Conversation Input",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    private var sendActionBarViewModel: SendActionBarViewModel?
    private var missingActionBarProviders: [String] = []
    private var actionBarInputObserver: ActionBarInputObserver?
    private var actionBarConversationObserver: ActionBarConversationObserver?

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Conversation Input", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }

        let input = kernel.resolveProvider((any ConversationInputProviding).self)
        let sender = kernel.resolveProvider((any MessageSendingProviding).self)
        let metrics = kernel.resolveProvider((any PerformanceMetricsProviding).self)
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let conversationState = kernel.resolveProvider((any ConversationStateProviding).self)

        var missingProviders: [String] = []
        if input == nil { missingProviders.append("ConversationInputProviding") }
        if sender == nil { missingProviders.append("MessageSendingProviding") }
        if conversations == nil { missingProviders.append("ConversationManaging") }
        if conversationState == nil { missingProviders.append("ConversationStateProviding") }
        if let input, let sender, let conversations, let conversationState {
            sendActionBarViewModel = SendActionBarViewModel(
                input: input,
                sender: sender,
                conversations: conversations,
                conversationState: conversationState
            )
        } else {
            sendActionBarViewModel = nil
        }
        missingActionBarProviders = missingProviders
        let actionBarViewModel = sendActionBarViewModel
        let actionBarMissingProviders = missingActionBarProviders

        // 1. 输入框上方的挂起图片预览
        chat.addItems([
            ChatSectionItem(
                id: "\(id).attachment-preview",
                order: 899,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                AttachmentPreviewView(sender: sender)
            },
        ])

        // 2. 底部固定输入框
        chat.addItems([
            ChatSectionItem(
                id: id,
                order: 900,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView(input: input, sender: sender, metrics: metrics)
            },
        ])

        // 3. Action Bar 发送/停止按钮
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).send-button",
                placement: .actionTrailing
            ) {
                SendActionBarButton(
                    viewModel: actionBarViewModel,
                    missingProviders: actionBarMissingProviders
                )
            },
        ])
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        guard let viewModel = sendActionBarViewModel,
              let input = kernel.resolveProvider((any ConversationInputProviding).self) else {
            Self.logger.error("\(Self.t)Failed to initialize SendActionBar observers: required providers unavailable")
            return
        }

        guard let sender = kernel.resolveProvider((any MessageSendingProviding).self) else {
            Self.logger.error("Failed to initialize ActionBarInputObserver: MessageSendingProviding unavailable")
            return
        }
        actionBarInputObserver = ActionBarInputObserver(input: input, sender: sender, viewModel: viewModel)

        // 3. 对话切换时清空输入框
        if let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            actionBarConversationObserver = ActionBarConversationObserver(
                conversations: conversations,
                input: input
            )
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        actionBarInputObserver?.cancel()
        actionBarInputObserver = nil
        sendActionBarViewModel?.stopObservingConversationState()
        actionBarConversationObserver?.cancel()
        actionBarConversationObserver = nil
        sendActionBarViewModel = nil
        missingActionBarProviders = []
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "\(id).attachment-preview")
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).send-button")
    }
}
