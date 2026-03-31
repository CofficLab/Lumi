import SwiftUI
import MagicKit

/// 会话列表空状态视图
struct ConversationListEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.system(size: 24))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "No conversations", table: "ConversationList"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ConversationListEmptyView()
        .frame(width: 220, height: 100)
}