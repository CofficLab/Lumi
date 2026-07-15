import LumiCoreKit
import LumiLocalizationKit
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
                        AppSettingRow(title: LumiLocalization.string("Name", bundle: .module), description: bundleInfo.name, icon: "app") {
                            EmptyView()
                        }
                        Divider()
                            .padding(.vertical, 8)
                        AppSettingRow(title: LumiLocalization.string("Bundle ID", bundle: .module), description: bundleInfo.bundleIdentifier, icon: "number") {
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
