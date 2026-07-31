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

            Text("No conversation selected")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Type a message and press Enter to start a new conversation.")
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
