import LumiUI
import ProviderDocsView
import SwiftUI

/// 通用设置详情视图 —— 复刻旧版 LumiApp（SettingsPlugin.GeneralSettingsView）
/// 设置窗口「通用」标签页：四个分组卡片，逐行、逐文案一致。
struct GeneralSettingsDetailView: View {
    let version: String?
    let docsProvider: (any DocsViewProviding)?

    /// 是否展示说明书浏览器。
    @State private var isPresentingManuals = false

    /// App bundle 元数据（名称 / 包名 / 版本 / 构建）。
    private let bundleInfo = AppBundleInfo()

    /// 所有提供了说明书的文档条目（来自 `DocsViewProviding`）。
    private var manuals: [DocsEntry] {
        docsProvider?.manualEntries ?? []
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                onboardingSection
                lumiSection
                websiteSection
                updatesSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isPresentingManuals) {
            if !manuals.isEmpty {
                ManualsBrowserView(manuals: manuals)
            }
        }
    }

    // MARK: - 新手引导

    private var onboardingSection: some View {
        AppSettingSection(
            title: "新手引导",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "重新查看新手引导",
                    description: "重放首次启动引导流程。",
                    icon: "graduationcap"
                ) {
                    AppButton(
                        "开始",
                        systemImage: "arrow.right",
                        style: .secondary,
                        size: .small
                    ) {
                        // 与旧版一致：广播重放引导请求，由宿主监听并展示。
                        NotificationCenter.default.post(
                            name: .lumiShowOnboarding,
                            object: nil,
                            userInfo: [LumiOnboardingNotification.resetKey: true]
                        )
                    }
                }

                if !manuals.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: "说明书",
                        description: "各功能的使用指南。",
                        icon: "book"
                    ) {
                        AppButton(
                            "打开",
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
    }

    // MARK: - Lumi（应用信息）

    private var lumiSection: some View {
        AppSettingSection(
            title: "Lumi",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "Name",
                    description: bundleInfo.name,
                    icon: "app"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: "Bundle ID",
                    description: bundleInfo.bundleIdentifier,
                    icon: "number"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: "Version",
                    description: bundleInfo.version ?? "Not Set",
                    icon: "info.circle"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: "Build",
                    description: bundleInfo.build ?? "Not Set",
                    icon: "hammer"
                ) {
                    EmptyView()
                }
            }
        }
    }

    // MARK: - 网站

    private var websiteSection: some View {
        AppSettingSection(
            title: "网站",
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: "官方网站",
                description: "coffic.cn/lumi",
                icon: "globe"
            ) {
                AppButton(
                    "访问",
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
    }

    // MARK: - 更新

    /// 与旧版一致：`allowsAppUpdates` 的宿主（Lumi 直营）展示「检查更新」行，
    /// 点击广播 `checkForUpdates` 通知，由宿主（如 Sparkle 更新插件）消费。
    private var updatesSection: some View {
        AppSettingSection(
            title: "Updates",
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: "Check for Updates",
                description: "Check whether a newer version of Lumi is available.",
                icon: "arrow.down.circle"
            ) {
                AppButton(
                    "Check...",
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

// MARK: - Onboarding 通知

/// 与旧版 KernelLumi.KernelEvents 一致的通知名与重置 key。
enum LumiOnboardingNotification {
    /// 重放新手引导时置 true，宿主据此强制重置引导进度。
    static let resetKey = "reset"
}

extension Notification.Name {
    /// 请求展示/重放新手引导（`Onboarding.Show`）。
    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")
}
