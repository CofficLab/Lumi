import LumiUI
import SwiftUI
import KernelLumi

/// 主题服务不可用时的标题工具栏错误视图
struct ThemeToolbarErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    var pluginName: String = "Theme Toolbar"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.appMicro)
                .foregroundColor(.red)

            Text("\(pluginName): \(LumiPluginLocalization.string("Service unavailable", bundle: .module))")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Theme Toolbar Error") {
    ThemeToolbarErrorView()
}
#endif
