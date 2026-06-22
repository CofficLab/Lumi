import LumiUI
import SwiftUI

struct AboutPage: View {
    private let bundleInfo = AppBundleInfo()

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: "Lumi", titleAlignment: .leading) {
                    VStack(spacing: 0) {
                        AppSettingRow(title: "名称", description: bundleInfo.name, icon: "app") {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(title: "Bundle ID", description: bundleInfo.bundleIdentifier, icon: "number") {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(
                            title: "版本",
                            description: bundleInfo.version ?? "未设置",
                            icon: "info.circle"
                        ) {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(
                            title: "构建",
                            description: bundleInfo.build ?? "未设置",
                            icon: "hammer"
                        ) {
                            EmptyView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
