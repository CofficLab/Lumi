import SwiftUI
import LumiUI

/// 设置侧边栏头部 - 应用信息
struct SettingsSidebarHeaderView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        let appInfo = AppInfo()

        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 50)

            // App 图标
            LogoView(scene: .about)
                .frame(width: 64, height: 64)

            // App 名称
            Text(appInfo.name)
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)

            // 版本和 Build 信息
            VStack(alignment: .center, spacing: 2) {
                Text("v\(appInfo.version ?? "Unknown")")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)

                Text("Build \(appInfo.build ?? "Unknown")")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Spacer().frame(height: 16)
        }
    }
}

#Preview {
    SettingsSidebarHeaderView()
}
