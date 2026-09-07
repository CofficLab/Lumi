import AppKit
import LumiUI
import ProviderDiagnostics
import ProviderDocsView
import ProviderUninstall
import SwiftUI
import UniformTypeIdentifiers

/// 通用设置详情视图 —— 设置窗口「通用」标签页：四个分组卡片。
struct GeneralSettingsDetailView: View {
    let version: String?
    let docsProvider: (any DocsViewProviding)?
    let diagnosticsProvider: (any DiagnosticsProviding)?
    let uninstallProvider: (any UninstallProviding)?
    let prepareForUninstall: (@MainActor () async -> Void)?

    /// 是否展示说明书浏览器。
    @State private var isPresentingManuals = false
    @State private var isExportingDiagnostics = false
    @State private var diagnosticsFeedback: String?
    @State private var isPresentingUninstall = false
    @State private var isScanningUninstall = false
    @State private var isUninstalling = false
    @State private var uninstallScan: UninstallScan?
    @State private var uninstallFeedback: String?
    @State private var uninstallConfirmation = ""
    @State private var removeKeychainCredentials = true
    @State private var removeApplication = true

    /// App bundle 元数据（名称 / 包名 / 版本 / 构建）。
    private let bundleInfo = AppBundleInfo()

    /// 所有提供了说明书的文档条目（来自 `DocsViewProviding`）。
    private var manuals: [DocsEntry] {
        docsProvider?.manualEntries ?? []
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
#if DEBUG
                debugHeader
#endif
                onboardingSection
                lumiSection
                websiteSection
                updatesSection
                diagnosticsSection
                uninstallSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isPresentingManuals) {
            if !manuals.isEmpty {
                ManualsBrowserView(manuals: manuals)
            }
        }
        .sheet(isPresented: $isPresentingUninstall) {
            uninstallSheet
        }
    }

    // MARK: - Debug Header

    #if DEBUG
    private var debugHeader: some View {
        HStack(spacing: 10) {
            Spacer()
            AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", style: .warning, size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
    }
    #endif

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
                        // 广播重放引导请求，由宿主监听并展示。
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
            title: LumiPluginLocalization.string("Lumi", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: LumiPluginLocalization.string("Name", bundle: .module),
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
                    title: LumiPluginLocalization.string("Version", bundle: .module),
                    description: bundleInfo.version ?? "Not Set",
                    icon: "info.circle"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: LumiPluginLocalization.string("Build", bundle: .module),
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

    /// `allowsAppUpdates` 的宿主（Lumi 直营）展示「检查更新」行，
    /// 点击广播 `checkForUpdates` 通知，由宿主（如 Sparkle 更新插件）消费。
    private var updatesSection: some View {
        AppSettingSection(
            title: LumiPluginLocalization.string("Updates", bundle: .module),
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: LumiPluginLocalization.string("Check for Updates", bundle: .module),
                description: "Check whether a newer version of Lumi is available.",
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

    // MARK: - 诊断日志

    private var diagnosticsSection: some View {
        AppSettingSection(
            title: "诊断日志",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "导出日志",
                    description: "打包最近的运行日志，便于提交问题反馈。",
                    icon: "doc.badge.arrow.up"
                ) {
                    AppButton(
                        isExportingDiagnostics ? "导出中…" : "导出",
                        systemImage: isExportingDiagnostics ? "hourglass" : "square.and.arrow.up",
                        style: .secondary,
                        size: .small
                    ) {
                        exportDiagnostics()
                    }
                    .disabled(isExportingDiagnostics || diagnosticsProvider == nil)
                }

                if let diagnosticsFeedback {
                    Divider()
                        .padding(.vertical, 8)
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
        AppSettingSection(
            title: "卸载 Lumi",
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: "彻底卸载 Lumi",
                description: "清除 Lumi 的插件数据、偏好设置、扩展数据和可选凭据。",
                icon: "trash"
            ) {
                AppButton(
                    "卸载…",
                    systemImage: "trash",
                    style: .destructive,
                    size: .small
                ) {
                    beginUninstall()
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

            if isScanningUninstall {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检查 Lumi 数据…")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            } else if let uninstallScan {
                uninstallSummary(scan: uninstallScan)
            }

            if let uninstallFeedback {
                Text(uninstallFeedback)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Divider()

            if let uninstallScan, uninstallScan.keychainTargetCount > 0 {
                Toggle("同时删除 Keychain 中的 API Key、密码和凭据", isOn: $removeKeychainCredentials)
                    .font(.appCaption)
            }

            Toggle("同时将 Lumi 应用移到废纸篓", isOn: $removeApplication)
                .font(.appCaption)

            VStack(alignment: .leading, spacing: 6) {
                Text("请输入“删除 Lumi 数据”以确认")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                TextField("删除 Lumi 数据", text: $uninstallConfirmation)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                AppButton("取消", style: .ghost, size: .small) {
                    isPresentingUninstall = false
                }
                AppButton(
                    isUninstalling ? "卸载中…" : "永久删除并卸载",
                    systemImage: isUninstalling ? "hourglass" : "trash.fill",
                    style: .destructive,
                    size: .small
                ) {
                    performUninstall()
                }
                .disabled(
                    isScanningUninstall
                    || isUninstalling
                    || uninstallConfirmation != UninstallOptions.confirmationPhrase
                    || uninstallProvider == nil
                )
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    @ViewBuilder
    private func uninstallSummary(scan: UninstallScan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("将处理 \(scan.targets.count) 项 Lumi 数据，总计 \(formattedBytes(scan.totalSizeInBytes))。")
                .font(.appBody)

            ForEach(scan.targets.prefix(8)) { target in
                HStack(spacing: 8) {
                    Image(systemName: target.isSensitive ? "key.fill" : "folder")
                        .foregroundStyle(target.isSensitive ? .orange : .secondary)
                    Text(target.kind.displayName)
                        .font(.appCaption)
                    Spacer()
                    if target.sizeInBytes > 0 {
                        Text(formattedBytes(target.sizeInBytes))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if scan.targets.count > 8 {
                Text("还有 \(scan.targets.count - 8) 项，将在确认后一起处理。")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @MainActor
    private func beginUninstall() {
        guard let uninstallProvider else {
            uninstallFeedback = "卸载服务暂不可用。"
            isPresentingUninstall = true
            return
        }

        uninstallFeedback = nil
        uninstallConfirmation = ""
        removeKeychainCredentials = true
        removeApplication = true
        uninstallScan = nil
        isPresentingUninstall = true
        isScanningUninstall = true

        Task { @MainActor in
            uninstallScan = await uninstallProvider.scan()
            isScanningUninstall = false
        }
    }

    @MainActor
    private func performUninstall() {
        guard let uninstallProvider else {
            uninstallFeedback = "卸载服务暂不可用。"
            return
        }

        isUninstalling = true
        uninstallFeedback = nil
        NotificationCenter.default.post(name: .lumiWillUninstall, object: nil)

        Task { @MainActor in
            defer { isUninstalling = false }
            do {
                await prepareForUninstall?()
                let result = try await uninstallProvider.uninstall(options: UninstallOptions(
                    confirmation: uninstallConfirmation,
                    removeKeychainCredentials: removeKeychainCredentials,
                    removeApplication: removeApplication
                ))

                if result.succeeded {
                    uninstallFeedback = result.applicationMovedToTrash
                        ? "Lumi 已卸载，应用已移到废纸篓。"
                        : "Lumi 数据已清除。"
                    if result.applicationMovedToTrash {
                        try? await Task.sleep(for: .milliseconds(700))
                        NSApplication.shared.terminate(nil)
                    }
                } else {
                    uninstallFeedback = "部分数据未能清除，应用未移除：\n"
                        + result.failures.map { "\($0.location)：\($0.message)" }.joined(separator: "\n")
                }
            } catch {
                uninstallFeedback = "卸载失败：\(error.localizedDescription)"
            }
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    @MainActor
    private func exportDiagnostics() {
        guard let diagnosticsProvider else {
            diagnosticsFeedback = "日志服务暂不可用。"
            return
        }

        isExportingDiagnostics = true
        diagnosticsFeedback = nil

        Task { @MainActor in
            defer { isExportingDiagnostics = false }

            do {
                let archive = try await diagnosticsProvider.makeDiagnosticsArchive()
                defer { try? FileManager.default.removeItem(at: archive.url) }
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.zip]
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = archive.filename
                panel.message = "选择诊断日志保存位置"

                guard panel.runModal() == .OK, let destination = panel.url else {
                    diagnosticsFeedback = "已取消导出。"
                    return
                }

                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: archive.url, to: destination)
                diagnosticsFeedback = "日志已导出：\(destination.lastPathComponent)"
            } catch {
                diagnosticsFeedback = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    private func openDataDirectory() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
        guard let url = appSupport else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
    #endif
}

// MARK: - Onboarding 通知

/// 通知名与重置 key。
enum LumiOnboardingNotification {
    /// 重放新手引导时置 true，宿主据此强制重置引导进度。
    static let resetKey = "reset"
}

extension Notification.Name {
    /// 请求展示/重放新手引导（`Onboarding.Show`）。
    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")
}
