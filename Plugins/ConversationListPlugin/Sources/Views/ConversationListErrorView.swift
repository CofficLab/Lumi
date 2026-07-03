import LumiCoreKit
import LumiUI
import SwiftUI

/// 会话列表服务不可用时的错误视图（用于 Rail Tab 面板内显示）
struct ConversationListErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.appTitle)
                .foregroundColor(.red)

            Text(LumiPluginLocalization.string("Service unavailable", bundle: .module))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Unable to load conversations", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Text(LumiPluginLocalization.string("Please restart the app", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Error View") {
    ConversationListErrorView()
        .frame(width: 300, height: 400)
}
#endif
