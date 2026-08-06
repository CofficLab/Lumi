import LumiUI
import SwiftUI

/// 未选择对话时的占位视图，提示用户输入消息并回车来创建新对话。
struct NoConversationSelectedView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text(LumiPluginLocalization.string("No conversation selected", bundle: .module))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Type a message and press Enter to start a new conversation.", bundle: .module))
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty state view when the conversation has no messages.
struct MessageEmptyStateView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text(LumiPluginLocalization.string("No messages yet", bundle: .module))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Start the conversation by sending a message.", bundle: .module))
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading state view shown while the message list is fetching data.
///
/// Renders a single SF Symbol with a gentle breathing (opacity) animation
/// so the user perceives the app as "alive" without visual noise.
struct MessageLoadingView: View {
    @LumiTheme private var theme

    /// Drives the breathing opacity animation.
    @State private var isBreathing = false

    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right")
            .font(.largeTitle)
            .foregroundStyle(theme.textSecondary)
            .opacity(isBreathing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear { isBreathing = true }
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…", bundle: .module)))
    }
}

#Preview("Message loading") {
    MessageLoadingView()
        .frame(width: 480, height: 600)
}
