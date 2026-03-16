import SwiftUI

/// 设置侧边栏头部 - 应用信息
struct SettingsSidebarHeaderView: View {
    var body: some View {
        let appInfo = AppInfo()

        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 50)

            // App 图标
            LogoView(variant: .about)
                .frame(width: 64, height: 64)

            // App 名称
            Text(appInfo.name)
                .font(.headline)
                .fontWeight(.semibold)

            // 版本和 Build 信息
            VStack(alignment: .center, spacing: 2) {
                Text("v\(appInfo.version ?? "Unknown")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Build \(appInfo.build ?? "Unknown")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 16)
        }
    }
}

#Preview {
    SettingsSidebarHeaderView()
}

