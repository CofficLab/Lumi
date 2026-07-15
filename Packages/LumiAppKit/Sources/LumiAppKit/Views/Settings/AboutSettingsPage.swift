import LumiCoreKit
import LumiUI
import SwiftUI

struct AboutSettingsPage: View {
    let lumiCore: LumiCoreAccessing
    private let bundleInfo = AppBundleInfo()

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                LogoView(scene: .about, lumiCore: lumiCore)
                    .frame(width: 72, height: 72)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

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
