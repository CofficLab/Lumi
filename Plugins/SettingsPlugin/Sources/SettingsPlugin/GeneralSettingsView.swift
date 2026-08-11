import AppKit
import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

/// "通用"设置页(原 LumiFactory 的 GeneralSettingsPage，宿主层现归 FactoryCore)。
struct GeneralSettingsView: View {
    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(
                    title: LumiPluginLocalization.string("Onboarding", bundle: .module),
                    titleAlignment: .leading
                ) {
                    AppSettingRow(
                        title: LumiPluginLocalization.string("Replay Onboarding", bundle: .module),
                        description: LumiPluginLocalization.string("Replay the first-run onboarding flow.", bundle: .module),
                        icon: "graduationcap"
                    ) {
                        AppButton(
                            LumiPluginLocalization.string("Start", bundle: .module),
                            systemImage: "arrow.right",
                            style: .secondary,
                            size: .small
                        ) {
                            NotificationCenter.default.post(
                                name: .lumiShowOnboarding,
                                object: nil,
                                userInfo: [LumiOnboardingNotification.resetKey: true]
                            )
                        }
                    }
                }

                AppSettingSection(
                    title: "Lumi",
                    titleAlignment: .leading
                ) {
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
                    title: LumiPluginLocalization.string("Website", bundle: .module),
                    titleAlignment: .leading
                ) {
                    AppSettingRow(
                        title: LumiPluginLocalization.string("Official Website", bundle: .module),
                        description: "coffic.cn/lumi",
                        icon: "globe"
                    ) {
                        AppButton(
                            LumiPluginLocalization.string("Visit", bundle: .module),
                            systemImage: "arrow.up.forward.square",
                            style: .secondary,
                            size: .small
                        ) {
                            if let url = URL(string: "https://coffic.cn/lumi") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                if LumiRuntimeEnvironment.current.allowsAppUpdates {
                    AppSettingSection(
                        title: LumiPluginLocalization.string("Updates", bundle: .module),
                        titleAlignment: .leading
                    ) {
                        AppSettingRow(
                            title: LumiPluginLocalization.string("Check for Updates", bundle: .module),
                            description: LumiPluginLocalization.string(
                                "Check whether a newer version of Lumi is available.",
                                bundle: .module
                            ),
                            icon: "arrow.down.circle"
                        ) {
                            AppButton(
                                LumiPluginLocalization.string("Check...", bundle: .module),
                                systemImage: "arrow.triangle.2.circlepath",
                                style: .secondary,
                                size: .small
                            ) {
                                NotificationCenter.default.post(
                                    name: Notification.Name("checkForUpdates"),
                                    object: nil
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private let bundleInfo = AppBundleInfo()
}
