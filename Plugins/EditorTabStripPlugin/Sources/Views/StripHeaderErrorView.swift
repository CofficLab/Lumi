import LumiUI
import SwiftUI
import LumiKernel

/// 编辑器 Tab Strip 服务不可用时的错误视图
struct StripHeaderErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var pluginName: String = "Editor Tab Strip"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.red)

            Text("\(pluginName): \(LumiPluginLocalization.string("Editor service unavailable", bundle: .module))")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Strip Error View") {
    StripHeaderErrorView()
}
#endif
