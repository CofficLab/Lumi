import SwiftUI

/// 设置侧边栏头部 - 应用信息
struct SettingsSidebarHeaderView: View {
    var body: some View {
        let appInfo = AppInfo()

        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 50)

            // App 图标
            LogoView(scene: .about)
                .frame(width: 64, height: 64)

            // App 名称
            Text(appInfo.name)
                .font(.system(size: 15, weight: .medium))

            // 版本和 Build 信息
            VStack(alignment: .center, spacing: 2) {
                Text("v\(appInfo.version ?? "Unknown")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "98989E"))

                Text("Build \(appInfo.build ?? "Unknown")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "98989E"))
            }

            Spacer().frame(height: 16)
        }
    }
}

#Preview {
    SettingsSidebarHeaderView()
}
