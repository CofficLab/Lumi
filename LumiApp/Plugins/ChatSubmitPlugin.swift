import LumiCoreKit
import LumiUI
import PluginChatSubmit
import SwiftUI
import os

/// 聊天发送控制插件
///
/// 在右侧栏底部工具栏注入发送/停止按钮。
/// 通过窗口级 VM 读取草稿、附件、发送状态，并触发入队或取消。
actor ChatSubmitPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-submit")

    nonisolated static let emoji = "🚀"
    nonisolated static let verbose: Bool = true
    static let id = PluginChatSubmit.ChatSubmitPlugin.id
    static let displayName = PluginChatSubmit.ChatSubmitPlugin.displayName
    static let description = PluginChatSubmit.ChatSubmitPlugin.description
    static let iconName = PluginChatSubmit.ChatSubmitPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatSubmit.ChatSubmitPlugin.category) }
    static var order: Int { PluginChatSubmit.ChatSubmitPlugin.order }
    static let shared = ChatSubmitPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        PluginChatSubmit.ChatSubmitPlugin.shared.addSidebarTrailingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "chat-submit" else { return nil }
        return AnyView(ChatSubmitToolbarButton())
    }
}

// MARK: - Toolbar Button View

/// 聊天发送/停止按钮
private struct ChatSubmitToolbarButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var taskCancellationVM: WindowTaskCancellationVM
    @EnvironmentObject private var attachmentsVM: WindowAttachmentsVM
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM
    @EnvironmentObject private var messageQueueVM: WindowMessageQueueVM
    @EnvironmentObject private var chatDraftVM: WindowChatDraftVM
    @Environment(\.windowContainer) private var windowContainer

    private var activeInputQueueVM: WindowInputQueueVM {
        windowContainer?.inputQueueVM ?? inputQueueVM
    }

    var body: some View {
        actionButton
    }
}

// MARK: - View

extension ChatSubmitToolbarButton {
    /// 当前会话是否处于发送处理中，用于发送/停止切换。
    private var isSendPipelineActive: Bool {
        guard let id = conversationVM.selectedConversationId else { return false }
        return messageQueueVM.isProcessing(for: id)
    }

    private var isSendDisabled: Bool {
        conversationVM.selectedConversationId == nil
            || !projectVM.isProjectSelected
            || (chatDraftVM.isEmpty && attachmentsVM.pendingAttachments.isEmpty)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isSendPipelineActive {
            Button(action: stopGenerating) {
                Image(systemName: "stop.fill")
                    .font(.appCallout)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(theme.error)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "Stop Generating", table: "AgentChat"))
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel(String(localized: "Stop Generating", table: "AgentChat"))
            .accessibilityHint(String(localized: "Stop Generating", table: "AgentChat"))
        } else {
            Button(action: submit) {
                Image(systemName: "paperplane.fill")
                    .font(.appCallout)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(isSendDisabled ? theme.textDisabled.opacity(0.5) : theme.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSendDisabled)
            .help(String(localized: "Send Message", table: "AgentChat"))
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityLabel(String(localized: "Send Message", table: "AgentChat"))
            .accessibilityHint(String(localized: "Send Message Hint", table: "AgentChat"))
        }
    }
}

// MARK: - Actions

extension ChatSubmitToolbarButton {
    private func submit() {
        let text = chatDraftVM.text
        chatDraftVM.clear()
        activeInputQueueVM.enqueueText(text)
    }

    private func stopGenerating() {
        guard let conversationId = conversationVM.selectedConversationId else { return }
        taskCancellationVM.requestCancel(conversationId: conversationId)
    }
}
