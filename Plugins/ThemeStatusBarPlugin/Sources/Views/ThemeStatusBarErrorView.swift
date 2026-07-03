import LumiUI
import SwiftUI

/// 主题服务不可用时的状态栏错误视图
struct ThemeStatusBarErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.red)

            Text(LumiPluginLocalization.string("Service unavailable", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Theme Status Bar Error") {
    ThemeStatusBarErrorView()
}
#endif
