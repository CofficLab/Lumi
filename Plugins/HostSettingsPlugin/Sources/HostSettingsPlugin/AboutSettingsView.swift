import LocalizationKit
import LumiUI
import SwiftUI

/// "关于"设置页(原 LumiFactory 的 AboutPage)。
struct AboutSettingsView: View {
    private let bundleInfo = AppBundleInfo()

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: "Lumi", titleAlignment: .leading) {
                    VStack(spacing: 0) {
                        AppSettingRow(
                            title: LumiLocalization.string("Name", bundle: .module),
                            description: bundleInfo.name,
                            icon: "app"
                        ) {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(
                            title: LumiLocalization.string("Bundle ID", bundle: .module),
                            description: bundleInfo.bundleIdentifier,
                            icon: "number"
                        ) {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(
                            title: LumiLocalization.string("Version", bundle: .module),
                            description: bundleInfo.version ?? LumiLocalization.string("Not Set", bundle: .module),
                            icon: "info.circle"
                        ) {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(
                            title: LumiLocalization.string("Build", bundle: .module),
                            description: bundleInfo.build ?? LumiLocalization.string("Not Set", bundle: .module),
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
