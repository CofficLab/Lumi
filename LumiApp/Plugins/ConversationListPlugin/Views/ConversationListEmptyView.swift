import LumiUI
import SwiftUI

/// 会话列表空状态视图
struct ConversationListEmptyView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)

            Text(String(localized: "No conversations", table: "ConversationList"))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
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
