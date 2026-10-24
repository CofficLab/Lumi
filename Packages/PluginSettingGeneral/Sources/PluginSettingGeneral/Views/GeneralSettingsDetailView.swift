import LumiUI
import ProviderAppUpdate
import ProviderDocsView
import ProviderUninstall
import SwiftUI
import UniformTypeIdentifiers

/// 通用设置详情视图 —— 设置窗口「通用」标签页：四个分组卡片。
///
/// 只依赖 `GeneralSettingsViewModel`；诊断导出、更新通道、卸载扫描等
/// 业务状态全部由 ViewModel 提供，外部操作经 Capability 收敛。
struct GeneralSettingsDetailView: View {
    let version: String?
    @ObservedObject var viewModel: GeneralSettingsViewModel

    /// 是否展示说明书浏览器（纯 UI 状态）。
    @State private var isPresentingManuals = false
    /// 是否展示卸载确认弹窗（纯 UI 状态）。
    @State private var isPresentingUninstall = false

    /// App bundle 元数据（名称 / 包名 / 版本 / 构建）。
    private let bundleInfo = AppBundleInfo()

    @LumiTheme private var theme

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                onboardingSection
                lumiSection
                websiteSection
                updatesSection
                diagnosticsSection
                uninstallSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.appSettingsCardStyleOverride, .subtle)
        .sheet(isPresented: $isPresentingManuals) {
            if !viewModel.manuals.isEmpty {
                ManualsBrowserView(manuals: viewModel.manuals)
            }
        }
        .sheet(isPresented: $isPresentingUninstall) {
            uninstallSheet
        }
    }

    // MARK: - 新手引导

    private var onboardingSection: some View {
        AppCard {
            AppSettingsSection(
                title: "新手引导"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "graduationcap")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("重新查看新手引导")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("重放首次启动引导流程。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            "开始",
                            systemImage: "arrow.right",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.replayOnboarding()
                        }
                        .disabled(!viewModel.isOnboardingAvailable)
                    }
                }

                if !viewModel.manuals.isEmpty {
                    AppSettingsRow {
                        HStack(spacing: 12) {
                            Image(systemName: "book")
                                .font(.appCallout)
                                .foregroundColor(theme.primary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("说明书")
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text("各功能的使用指南。")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

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
    }

    // MARK: - Lumi（应用信息）

    private var lumiSection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("Lumi")
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "app")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginLocalization.string("Name"))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(bundleInfo.name)
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        EmptyView()
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bundle ID")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(bundleInfo.bundleIdentifier)
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        EmptyView()
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginLocalization.string("Version"))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(bundleInfo.version ?? "Not Set")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        EmptyView()
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "hammer")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginLocalization.string("Build"))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(bundleInfo.build ?? "Not Set")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        EmptyView()
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "internaldrive")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("占用空间")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(viewModel.storageSizeDescription)
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            "打开数据库目录",
                            systemImage: "folder",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.openStorageDirectory()
                        }
                        .disabled(!viewModel.isStorageAvailable)
                    }
                }
            }
        }
    }

    // MARK: - 网站

    private var websiteSection: some View {
        AppCard {
            AppSettingsSection(
                title: "网站"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("官方网站")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("coffic.cn/lumi")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

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
        }
    }

    // MARK: - 更新

    /// `allowsAppUpdates` 的宿主（Lumi 直营）展示「检查更新」行，
    /// 点击广播 `checkForUpdates` 通知，由宿主（如 Sparkle 更新插件）消费。
    private var updatesSection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("Updates")
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginLocalization.string("Check for Updates"))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("Check whether a newer version of Lumi is available.")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            pluginLocalization.string("Check..."),
                            systemImage: "arrow.triangle.2.circlepath",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.checkForUpdates()
                        }
                    }
                }

                if viewModel.isUpdateChannelAvailable {
                    AppSettingsRow {
                        HStack(spacing: 12) {
                            Image(
                                systemName: viewModel.selectedUpdateChannel == .preview
                                    ? "flask"
                                    : "checkmark.seal"
                            )
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("更新通道")
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(
                                    viewModel.selectedUpdateChannel == .preview
                                        ? "获取 pre 分支发布的预览版本，可能包含未修复的问题。"
                                        : "获取 main 分支发布的稳定版本。"
                                )
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            Picker("更新通道", selection: $viewModel.selectedUpdateChannel) {
                                Text("稳定版").tag(AppUpdateChannel.stable)
                                Text("预览版").tag(AppUpdateChannel.preview)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 诊断日志

    private var diagnosticsSection: some View {
        AppCard {
            AppSettingsSection(
                title: "诊断日志"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("导出日志")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("打包最近的运行日志，便于提交问题反馈。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            viewModel.isExportingDiagnostics ? "导出中…" : "导出",
                            systemImage: viewModel.isExportingDiagnostics ? "hourglass" : "square.and.arrow.up",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.exportDiagnostics()
                        }
                        .disabled(viewModel.isExportingDiagnostics || !viewModel.isDiagnosticsAvailable)
                    }
                }

                if let diagnosticsFeedback = viewModel.diagnosticsFeedback {
                    Text(diagnosticsFeedback)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - 卸载 Lumi

    private var uninstallSection: some View {
        AppCard {
            AppSettingsSection(
                title: "卸载 Lumi"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("彻底卸载 Lumi")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("清除 Lumi 的插件数据、偏好设置、扩展数据和可选凭据。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            "卸载…",
                            systemImage: "trash",
                            style: .destructive,
                            size: .small
                        ) {
                            viewModel.beginUninstall()
                            isPresentingUninstall = true
                        }
                    }
                }
            }
        }
    }

    private var uninstallSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("彻底卸载 Lumi")
                .font(.appTitle)

            Text("此操作会永久删除 Lumi 自己保存的数据。用户项目、源码和导出的文件不会被删除。")
                .font(.appBody)
                .foregroundStyle(.secondary)

            if viewModel.isScanningUninstall {
                AppStatusBanner(kind: .loading, title: "正在检查 Lumi 数据…")
            } else if let uninstallScan = viewModel.uninstallScan {
                uninstallSummary(scan: uninstallScan)
            }

            if let uninstallFeedback = viewModel.uninstallFeedback {
                AppStatusBanner(kind: viewModel.uninstallFeedbackKind.bannerKind, title: uninstallFeedback)
                    .textSelection(.enabled)
            }

            AppDivider()

            VStack(spacing: 0) {
                AppSettingsToggleRow(
                    "同时将 Lumi 应用移到废纸篓",
                    systemImage: "trash",
                    isOn: $viewModel.removeApplication
                )

                if let uninstallScan = viewModel.uninstallScan, uninstallScan.keychainTargetCount > 0 {
                    AppSettingsToggleRow(
                        "同时删除 Keychain 中的 API Key、密码和凭据",
                        systemImage: "key.fill",
                        isOn: $viewModel.removeKeychainCredentials
                    )
                }
            }

            HStack {
                Spacer()
                AppButton("取消", style: .ghost, size: .small) {
                    isPresentingUninstall = false
                }
                AppButton(
                    viewModel.isUninstalling
                        ? "卸载中…"
                        : (viewModel.removeApplication ? "永久删除并卸载" : "清除数据并退出"),
                    systemImage: viewModel.isUninstalling ? "hourglass" : "trash.fill",
                    style: .destructive,
                    size: .small
                ) {
                    viewModel.performUninstall()
                }
                .disabled(
                    viewModel.isScanningUninstall
                    || viewModel.isUninstalling
                    || !viewModel.isUninstallAvailable
                )
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    @ViewBuilder
    private func uninstallSummary(scan: UninstallScan) -> some View {
        AppCard {
            AppSettingsSection(
                title: "将处理 \(scan.targets.count) 项 Lumi 数据，总计 \(formattedBytes(scan.totalSizeInBytes))。"
            ) {
                ForEach(Array(scan.targets.prefix(8).enumerated()), id: \.element.id) { _, target in
                    AppSettingsRow {
                        HStack(spacing: 12) {
                            Image(systemName: uninstallIcon(for: target))
                                .font(.appCallout)
                                .foregroundColor(theme.primary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.kind.displayName)
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(target.sizeInBytes > 0 ? formattedBytes(target.sizeInBytes) : "—")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            EmptyView()
                        }
                    }
                }

                if scan.targets.count > 8 {
                    Text("还有 \(scan.targets.count - 8) 项，将在确认后一起处理。")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
        }
    }

    private func uninstallIcon(for target: UninstallTarget) -> String {
        target.kind == .application ? "folder" : "key.fill"
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
