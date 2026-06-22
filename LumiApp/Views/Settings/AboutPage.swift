import LumiUI
import SwiftUI

struct AboutPage: View {
    private let bundleInfo = AppBundleInfo()

    var body: some View {
        AppSettingsContentScaffold {
            VStack(alignment: .leading, spacing: 18) {
                AppSettingsSection(title: "Lumi") {
                    AppSettingsReadOnlyRow("名称", badge: bundleInfo.name)
                    AppSettingsReadOnlyRow("Bundle ID", badge: bundleInfo.bundleIdentifier)
                    AppSettingsReadOnlyRow("版本", badge: bundleInfo.version ?? "未设置")
                    AppSettingsReadOnlyRow("构建", badge: bundleInfo.build ?? "未设置")
                }
            }
        }
    }
}
