import AppKit
import Darwin
import LumiUI
import ProviderAppUpdate
import ProviderDiagnostics
import ProviderDocsView
import ProviderOnboarding
import ProviderUninstall
import SwiftUI
import UniformTypeIdentifiers

/// 通用设置详情视图 —— 设置窗口「通用」标签页：四个分组卡片。
struct GeneralSettingsDetailView: View {
    let version: String?
    let docsProvider: (any DocsViewProviding)?
    let diagnosticsProvider: (any DiagnosticsProviding)?
    let updateProvider: (any AppUpdateChannelProviding)?
    let onboardingProvider: (any OnboardingProviding)?
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
    @State private var uninstallFeedbackKind: UninstallFeedbackKind = .info
    @State private var removeKeychainCredentials = true
    @State private var removeApplication = true
    @State private var selectedUpdateChannel: AppUpdateChannel = .stable

    /// App bundle 元数据（名称 / 包名 / 版本 / 构建）。
    private let bundleInfo = AppBundleInfo()

    /// 卸载反馈的语义类型，决定反馈横幅（`AppStatusBanner`）的样式。
    private enum UninstallFeedbackKind {
        case info
        case success
        case warning
        case error

        var bannerKind: AppStatusBanner.Kind {
            switch self {
            case .info: return .info
            case .success: return .success
            case .warning: return .warning
            case .error: return .error
            }
        }
    }

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
        .onAppear {
            selectedUpdateChannel = updateProvider?.channel ?? .stable
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
                        onboardingProvider?.replay()
                    }
                    .disabled(onboardingProvider == nil)
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
            VStack(spacing: 0) {
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

                if let updateProvider {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: "更新通道",
                        description: selectedUpdateChannel == .preview
                            ? "获取 pre 分支发布的预览版本，可能包含未修复的问题。"
                            : "获取 main 分支发布的稳定版本。",
                        icon: selectedUpdateChannel == .preview ? "flask" : "checkmark.seal"
                    ) {
                        Picker("更新通道", selection: $selectedUpdateChannel) {
                            Text("稳定版").tag(AppUpdateChannel.stable)
                            Text("预览版").tag(AppUpdateChannel.preview)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .onChange(of: selectedUpdateChannel) { _, channel in
                            updateProvider.setChannel(channel)
                        }
                    }
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
                AppStatusBanner(kind: .loading, title: "正在检查 Lumi 数据…")
            } else if let uninstallScan {
                uninstallSummary(scan: uninstallScan)
            }

            if let uninstallFeedback {
                AppStatusBanner(kind: uninstallFeedbackKind.bannerKind, title: uninstallFeedback)
                    .textSelection(.enabled)
            }

            AppDivider()

            if let uninstallScan, uninstallScan.keychainTargetCount > 0 {
                AppToggleRow(
                    title: "同时删除 Keychain 中的 API Key、密码和凭据",
                    systemImage: "key.fill",
                    isOn: $removeKeychainCredentials
                )
            }

            AppToggleRow(
                title: "同时将 Lumi 应用移到废纸篓",
                systemImage: "trash",
                isOn: $removeApplication
            )

            HStack {
                Spacer()
                AppButton("取消", style: .ghost, size: .small) {
                    isPresentingUninstall = false
                }
                AppButton(
                    isUninstalling
                        ? "卸载中…"
                        : (removeApplication ? "永久删除并卸载" : "清除数据并退出"),
                    systemImage: isUninstalling ? "hourglass" : "trash.fill",
                    style: .destructive,
                    size: .small
                ) {
                    performUninstall()
                }
                .disabled(
                    isScanningUninstall
                    || isUninstalling
                    || uninstallProvider == nil
                )
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    @ViewBuilder
    private func uninstallSummary(scan: UninstallScan) -> some View {
        AppCard(
            style: .subtle,
            cornerRadius: 10,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            showShadow: false
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("将处理 \(scan.targets.count) 项 Lumi 数据，总计 \(formattedBytes(scan.totalSizeInBytes))。")
                    .font(.appBody)

                ForEach(scan.targets.prefix(8)) { target in
                    AppInfoRow(
                        icon: target.isSensitive ? "key.fill" : "folder",
                        title: target.kind.displayName,
                        description: target.sizeInBytes > 0 ? formattedBytes(target.sizeInBytes) : "—",
                        tint: target.isSensitive ? .orange : .secondary
                    )
                }

                if scan.targets.count > 8 {
                    Text("还有 \(scan.targets.count - 8) 项，将在确认后一起处理。")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @MainActor
    private func beginUninstall() {
        guard let uninstallProvider else {
            uninstallFeedback = "卸载服务暂不可用。"
            uninstallFeedbackKind = .warning
            isPresentingUninstall = true
            return
        }

        uninstallFeedback = nil
        uninstallFeedbackKind = .info
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
            uninstallFeedbackKind = .warning
            return
        }

        isUninstalling = true
        uninstallFeedback = nil
        uninstallFeedbackKind = .info

        // 关闭确认弹窗，隐藏设置窗口，切换到与主窗口解耦的独立卸载浮层。
        // 内核停止后设置窗口可能暂时失去内容，浮层负责承载后续所有阶段。
        isPresentingUninstall = false
        NSApp.windows.forEach { $0.orderOut(nil) }
        UninstallOverlayWindowController.shared.show(
            phase: .running,
            onExit: { self.terminateAfterUninstall() },
            onClose: {
                UninstallOverlayWindowController.shared.close()
                self.restoreApplicationAfterUninstallFailure()
            }
        )
        NotificationCenter.default.post(name: .lumiWillUninstall, object: nil)

        Task { @MainActor in
            defer { isUninstalling = false }
            do {
                await prepareForUninstall?()
                let result = try await uninstallProvider.uninstall(options: UninstallOptions(
                    confirmation: UninstallOptions.confirmationPhrase,
                    removeKeychainCredentials: removeKeychainCredentials,
                    removeApplication: removeApplication
                ))

                if result.succeeded {
                    UninstallOverlayWindowController.shared.update(
                        phase: .succeeded(applicationMovedToTrash: result.applicationMovedToTrash)
                    )
                } else {
                    UninstallOverlayWindowController.shared.update(
                        phase: .failed(
                            detail: "部分数据未能清除，应用未移除：\n"
                                + result.failures.map { "\($0.location)：\($0.message)" }.joined(separator: "\n")
                        )
                    )
                }
            } catch {
                UninstallOverlayWindowController.shared.update(
                    phase: .failed(detail: "卸载失败：\(error.localizedDescription)")
                )
            }
        }
    }

    /// 卸载结束后退出当前进程。应用本体已经移到废纸篓时不能再依赖
    /// SwiftUI 窗口生命周期来触发退出，否则可能留下一个空壳窗口。
    @MainActor
    private func terminateAfterUninstall() {
        NSApp.hide(nil)
        NSApp.terminate(nil)

        // 如果某个 AppKit/第三方组件延迟了终止请求，短暂兜底后强制结束。
        // 卸载前内核已经完成 shutdown，数据清理也已经完成。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if NSApp.isRunning {
                Darwin.exit(EXIT_SUCCESS)
            }
        }
    }

    @MainActor
    private func restoreApplicationAfterUninstallFailure() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
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
