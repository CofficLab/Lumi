import SwiftUI
import LumiUI

/// 设置侧边栏头部 - 应用信息
struct SettingsSidebarHeaderView: View {
    private let appInfo = AppBundleInfo()

    var body: some View {
        AppSettingsSidebarHeader(
            name: appInfo.name,
            version: appInfo.version,
            build: appInfo.build
        ) {
            LogoView(scene: .about)
                .frame(width: 64, height: 64)
        }
    }
}

#Preview {
    SettingsSidebarHeaderView()
}
