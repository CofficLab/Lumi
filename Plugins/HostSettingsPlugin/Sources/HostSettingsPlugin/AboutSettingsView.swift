import AppUpdatePlugin
import LocalizationKit
import LumiUI
import SwiftUI

/// "About" settings page (originally `LumiFactory`'s AboutPage).
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

                AppSettingSection(
                    title: LumiLocalization.string("Updates", bundle: .module),
                    titleAlignment: .leading
                ) {
                    AppSettingRow(
                        title: LumiLocalization.string("Check for Updates", bundle: .module),
                        description: LumiLocalization.string(
                            "Check whether a newer version of Lumi is available.",
                            bundle: .module
                        ),
                        icon: "arrow.down.circle"
                    ) {
                        AppButton(
                            LumiLocalization.string("Check...", bundle: .module),
                            systemImage: "arrow.triangle.2.circlepath",
                            style: .secondary,
                            size: .small
                        ) {
                            UpdateService.shared.checkForUpdates()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
