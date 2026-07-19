import LumiUI
import SwiftUI
import LumiKernel

/// 会话列表空状态视图
public struct ConversationListEmptyView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)

            Text(LumiPluginLocalization.string("No conversations", bundle: .module))
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
