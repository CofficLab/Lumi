import SwiftUI
import LumiUI

/// 正在扫描相关文件状态视图
struct AppManagerScanningView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.appLargeTitle)
                    .foregroundColor(theme.primary)
                    .symbolRenderingMode(.hierarchical)
                
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(PluginAppManagerLocalization.string("Scanning related files..."))
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
