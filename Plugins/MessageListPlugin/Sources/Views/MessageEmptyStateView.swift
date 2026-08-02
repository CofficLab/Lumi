import LumiUI
import SwiftUI

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
