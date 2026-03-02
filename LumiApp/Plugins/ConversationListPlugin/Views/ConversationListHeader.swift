import SwiftUI
import MagicKit

/// 会话列表头部视图
struct ConversationListHeader: View {
    var body: some View {
        HStack {
            Image(systemName: "message.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text("对话历史")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

#Preview {
    ConversationListHeader()
        .frame(width: 220)
}
