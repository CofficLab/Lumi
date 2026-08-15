#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import LocalizationKit
import KernelLumi
import LumiUI
import SwiftUI

/// "通用"设置页(原 LumiFactory 的 GeneralSettingsPage，宿主层现归 FactoryCore)。
///
/// 「新手引导」分区除了重放引导外,还提供「说明书」入口,
/// 打开各插件贡献(`pluginManualView`)的说明书浏览器。
struct GeneralSettingsView: View {
    /// 内核。用于枚举提供说明书(`pluginManualView`)的插件。
    let kernel: KernelLumi

    /// 是否展示说明书浏览器。
    @State private var isPresentingManuals = false

    /// 所有提供了说明书的插件。不受启用状态影响——说明书是帮助内容,
    /// 禁用的插件依然可以查阅(便于用户了解功能后再决定是否启用)。
    private var manualPlugins: [LumiPlugin] {
        kernel.pluginManager.allPlugins
            .filter { $0.pluginManualView(kernel: kernel) != nil }
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(
                    title: LumiPluginLocalization.string("Onboarding", bundle: .module),
                    titleAlignment: .leading
                ) {
                    VStack(spacing: 0) {
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

                        if !manualPlugins.isEmpty {
                            Divider()
                                .padding(.vertical, 8)

                            AppSettingRow(
                                title: LumiPluginLocalization.string("User Manuals", bundle: .module),
                                description: LumiPluginLocalization.string(
                                    "Step-by-step guides for every feature.",
                                    bundle: .module
                                ),
                                icon: "book"
                            ) {
                                AppButton(
                                    LumiPluginLocalization.string("Open", bundle: .module),
                                    systemImage: "book.pages",
                                    style: .secondary,
                                    size: .small
                                ) {
                                    isPresentingManuals = true
                                }
                            }
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
                                #if canImport(AppKit)
                                NSWorkspace.shared.open(url)
                                #elseif canImport(UIKit)
                                UIApplication.shared.open(url)
                                #endif
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
        .sheet(isPresented: $isPresentingManuals) {
            ManualsBrowserView(kernel: kernel)
        }
    }

    private let bundleInfo = AppBundleInfo()
}
