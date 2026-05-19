import MagicKit
import SwiftUI
import os

/// 聊天无会话遮罩插件
///
/// 负责在输入区没有选中会话时展示禁用遮罩。
actor ChatNoConversationOverlayPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-no-conversation-overlay")

    nonisolated static let emoji = "🚫"
    nonisolated static let verbose: Bool = false
    static let id = "ChatNoConversationOverlay"
    static let displayName = String(localized: "Chat No Conversation Overlay", table: "AgentChat")
    static let description = String(localized: "Show an overlay on the chat input when no conversation is selected", table: "AgentChat")
    static let iconName = "bubble.left.and.exclamationmark.bubble.right"
    static var order: Int { 97 }
    nonisolated static let enable: Bool = true
    static let shared = ChatNoConversationOverlayPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addChatInputOverlayViews(activeIcon: String?) -> [AnyView] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [AnyView(ChatNoConversationOverlayView())]
    }
}

// MARK: - Overlay View

private struct ChatNoConversationOverlayView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    private var shouldShow: Bool {
        conversationVM.selectedConversationId == nil
    }

    var body: some View {
        if shouldShow {
            overlayContent
        }
    }
}

// MARK: - View

extension ChatNoConversationOverlayView {
    private var overlayContent: some View {
        let theme = themeVM.activeAppTheme
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.workspaceBackgroundColor().opacity(0.9))

            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.workspaceTertiaryTextColor())

                Text(String(localized: "Please create or select a conversation first", table: "AgentChat"))
                    .font(.subheadline)
                    .foregroundStyle(theme.workspaceSecondaryTextColor())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
        }
    }
}
