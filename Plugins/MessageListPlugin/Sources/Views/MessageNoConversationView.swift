import LumiUI
import SwiftUI

/// View shown when no conversation is selected.
struct MessageNoConversationView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text("No conversation selected")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Select or create a conversation to start chatting.")
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
