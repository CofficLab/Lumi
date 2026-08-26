import KernelCore
import LumiUI
import os
import ProviderChatSection
import ProviderConversation
import ProviderConversationInput
import ProviderMessageSender
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
    private var actionBarSendingObserver: ActionBarSendingObserver?
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

        var missingProviders: [String] = []
        if input == nil { missingProviders.append("ConversationInputProviding") }
        if sender == nil { missingProviders.append("MessageSendingProviding") }
        if let input, let sender {
            sendActionBarViewModel = SendActionBarViewModel(input: input, sender: sender)
        } else {
            sendActionBarViewModel = nil
        }
        missingActionBarProviders = missingProviders
        let actionBarViewModel = sendActionBarViewModel
        let actionBarMissingProviders = missingActionBarProviders

        // 1. 底部固定输入框
        chat.addItems([
            ChatSectionItem(
                id: id,
                order: 900,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView(input: input, sender: sender)
            },
        ])

        // 2. Action Bar 发送/停止按钮
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
              let input = kernel.resolveProvider((any ConversationInputProviding).self),
              let sender = kernel.resolveProvider((any MessageSendingProviding).self) else {
            Self.logger.error("\(Self.t)Failed to initialize SendActionBar observers: required providers unavailable")
            return
        }

        actionBarInputObserver = ActionBarInputObserver(input: input, viewModel: viewModel)
        actionBarSendingObserver = ActionBarSendingObserver(sender: sender, viewModel: viewModel)

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
        actionBarSendingObserver?.cancel()
        actionBarSendingObserver = nil
        actionBarConversationObserver?.cancel()
        actionBarConversationObserver = nil
        sendActionBarViewModel = nil
        missingActionBarProviders = []
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).send-button")
    }
}
