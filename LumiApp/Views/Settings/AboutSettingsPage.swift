import LumiUI
import SwiftUI

struct AboutSettingsPage: View {
    private let bundleInfo = AppBundleInfo()

    var body: some View {
        SettingsPageScaffold(title: "关于", subtitle: "应用信息") {
            LogoView(scene: .about)
                .frame(width: 72, height: 72)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            AppSettingsSection(title: "Lumi") {
                AppSettingsReadOnlyRow("名称", badge: bundleInfo.name)
                AppSettingsReadOnlyRow("Bundle ID", badge: bundleInfo.bundleIdentifier)
                AppSettingsReadOnlyRow("版本", badge: bundleInfo.version ?? "未设置")
                AppSettingsReadOnlyRow("构建", badge: bundleInfo.build ?? "未设置")
            }
        }
    }
}
