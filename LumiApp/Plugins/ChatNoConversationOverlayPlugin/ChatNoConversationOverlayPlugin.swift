import MagicKit
import SwiftUI
import os

/// 聊天无会话遮罩插件
///
/// 通过 `wrapRightSidebarRoot` 包裹右侧栏内容，
/// 在未选中会话时覆盖输入区域显示提示遮罩。
actor ChatNoConversationOverlayPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-no-conversation-overlay")

    nonisolated static let emoji = "🚫"
    nonisolated static let verbose: Bool = false
    static let id = "ChatNoConversationOverlay"
    static let displayName = String(localized: "Chat No Conversation Overlay", table: "ChatNoConversationOverlay")
    static let description = String(localized: "Show an overlay on the chat input when no conversation is selected", table: "ChatNoConversationOverlay")
    static let iconName = "bubble.left.and.exclamationmark.bubble.right"
    static var order: Int { 97 }
    nonisolated static let enable: Bool = true
    static let shared = ChatNoConversationOverlayPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func wrapRightSidebarRoot(_ content: AnyView, activeIcon: String?) -> AnyView {
        guard activeIcon == EditorPlugin.iconName else { return content }
        return AnyView(ChatNoConversationOverlayWrapper(content: content))
    }
}

// MARK: - Overlay Wrapper

private struct ChatNoConversationOverlayWrapper: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    let content: AnyView

    private var shouldShow: Bool {
        conversationVM.selectedConversationId == nil
    }

    var body: some View {
        ZStack {
            content

            if shouldShow {
                overlayContent
            }
        }
    }
}

// MARK: - View

extension ChatNoConversationOverlayWrapper {
    private var overlayContent: some View {
        let theme = themeVM.activeAppTheme
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.workspaceBackgroundColor().opacity(0.9))

            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.workspaceTertiaryTextColor())

                Text(String(localized: "Please create or select a conversation first", table: "ChatNoConversationOverlay"))
                    .font(.subheadline)
                    .foregroundStyle(theme.workspaceSecondaryTextColor())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
}
