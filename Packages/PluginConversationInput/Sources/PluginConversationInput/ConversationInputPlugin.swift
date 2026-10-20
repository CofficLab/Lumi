import KernelCore
import LumiUI
import os
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderMessageSender
import ProviderPerformanceMetrics
import LumiLoggingKit
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

    private var capability: ConversationInputCapabilityAdapter?
    private var inputViewModel: ConversationInputViewModel?
    private var sendActionBarViewModel: SendActionBarViewModel?
    private var missingActionBarProviders: [String] = []
    private var inputObserver: ConversationInputObserver?
    private var actionBarInputObserver: ActionBarInputObserver?
    private var actionBarConversationObserver: ActionBarConversationObserver?
    private var sendActionBarStateObserver: SendActionBarConversationObserver?

    public init() {}

    public var name: String {
        pluginLocalization.string("Conversation Input")
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }

        let input = kernel.resolveProvider((any ConversationInputProviding).self)
        let blocks = kernel.resolveProvider((any ConversationInputBlockProviding).self)
        let sender = kernel.resolveProvider((any MessageSendingProviding).self)
        let metrics = kernel.resolveProvider((any PerformanceMetricsProviding).self)
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let conversationState = kernel.resolveProvider((any ConversationStateProviding).self)

        // 组装层：Capability → ViewModel → Observer → View。
        let capability = ConversationInputCapabilityAdapter(
            input: input,
            blocks: blocks,
            sender: sender,
            conversations: conversations,
            conversationState: conversationState,
            metrics: metrics
        )
        self.capability = capability

        let inputViewModel = ConversationInputViewModel(capability: capability)
        self.inputViewModel = inputViewModel

        inputObserver?.cancel()
        inputObserver = ConversationInputObserver(
            capability: capability,
            viewModel: inputViewModel
        )

        var missingProviders: [String] = []
        if input == nil { missingProviders.append("ConversationInputProviding") }
        if sender == nil { missingProviders.append("MessageSendingProviding") }
        if conversations == nil { missingProviders.append("ConversationManaging") }
        if conversationState == nil { missingProviders.append("ConversationStateProviding") }
        if input != nil, sender != nil, conversations != nil, conversationState != nil {
            sendActionBarViewModel = SendActionBarViewModel(capability: capability)
        } else {
            sendActionBarViewModel = nil
        }
        // 发送按钮只经 `ActionBarInputObserver`（addTextObserver）获知文本变化，
        // 而该通知只覆盖逐键输入。把「直接写入」也接到按钮上，否则粘贴、
        // 语音输入与 UI 测试的 typeText 会让按钮停在 disabled。
        let actionBar = sendActionBarViewModel
        inputViewModel.onTextWritten = { [weak actionBar] text in
            actionBar?.updateInputText(text)
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
            ) { [inputViewModel] in
                AttachmentPreviewView(viewModel: inputViewModel)
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
            ) { [inputViewModel] in
                ConversationInputView(viewModel: inputViewModel)
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
        // UI 测试夹具：让附件预览稳定渲染出可点击的 ✕（拖放在 XCUITest 下不可靠，
        // 详见 AttachmentPreviewUITestingSupport 的说明）。
        //
        // - Important: 调用点必须与夹具的 `#if DEBUG` 守卫**同等包裹**。
        //   夹具整体定义在 `#if DEBUG` 内，只包住调用语句会让 Release 构建报
        //   `cannot find 'AttachmentPreviewUITestingSupport' in scope`——本地 Debug
        //   全绿而 CI Release 失败。
        #if DEBUG
        if let sender = kernel.resolveProvider((any MessageSendingProviding).self) {
            AttachmentPreviewUITestingSupport.seedAttachments(into: sender)
        }
        #endif

        guard let capability,
              let viewModel = sendActionBarViewModel else {
            Self.logger.error("\(Self.t)Failed to initialize SendActionBar observers: required providers unavailable")
            return
        }

        actionBarInputObserver = ActionBarInputObserver(
            capability: capability,
            viewModel: viewModel
        )

        sendActionBarStateObserver = SendActionBarConversationObserver(
            capability: capability,
            viewModel: viewModel
        )

        // 3. 对话切换时清空输入框
        if let inputViewModel {
            actionBarConversationObserver = ActionBarConversationObserver(
                capability: capability,
                viewModel: inputViewModel
            )
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        inputObserver?.cancel()
        inputObserver = nil
        actionBarInputObserver?.cancel()
        actionBarInputObserver = nil
        sendActionBarStateObserver?.cancel()
        sendActionBarStateObserver = nil
        actionBarConversationObserver?.cancel()
        actionBarConversationObserver = nil
        sendActionBarViewModel = nil
        inputViewModel = nil
        capability = nil
        missingActionBarProviders = []
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "\(id).attachment-preview")
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).send-button")
    }
}
