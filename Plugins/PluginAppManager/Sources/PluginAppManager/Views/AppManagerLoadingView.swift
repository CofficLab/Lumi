import SwiftUI
import LumiUI

/// 应用管理器加载状态视图
struct AppManagerLoadingView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var message: String = PluginAppManagerLocalization.string("Scanning applications...")

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
