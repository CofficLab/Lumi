import AppKit
import Darwin
import Foundation
import LumiUI
import ProviderAppUpdate
import ProviderDocsView
import ProviderUninstall
import SwiftUI

/// 通用设置页的唯一数据来源。
///
/// 负责诊断导出、更新通道、卸载扫描/执行等业务状态；所有外部操作
/// 经各 `GeneralSettings*Capability` 收敛，View 只读取本 ViewModel。
@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    /// 卸载反馈的语义类型，决定反馈横幅（`AppStatusBanner`）的样式。
    enum UninstallFeedbackKind {
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

    private let docsCapability: any GeneralSettingsDocsCapability
    private let updateChannelCapability: any GeneralSettingsUpdateChannelCapability
    private let diagnosticsCapability: any GeneralSettingsDiagnosticsCapability
    private let storageCapability: any GeneralSettingsStorageCapability
    private let uninstallCapability: any GeneralSettingsUninstallCapability

    // MARK: - Published State (供 View 展示)

    /// 所有提供了说明书的文档条目。
    @Published private(set) var manuals: [DocsEntry] = []

    /// Lumi 数据根目录的实际磁盘占用；nil 表示仍在计算或存储服务不可用。
    @Published private(set) var storageSizeInBytes: Int64?

    /// 当前更新通道（默认稳定版）。
    @Published var selectedUpdateChannel: AppUpdateChannel = .stable {
        didSet {
            guard selectedUpdateChannel != oldValue else { return }
            updateChannelCapability.setUpdateChannel(selectedUpdateChannel)
        }
    }

    // 诊断导出
    @Published private(set) var isExportingDiagnostics = false
    @Published private(set) var diagnosticsFeedback: String?

    // 卸载流程
    @Published private(set) var uninstallScan: UninstallScan?
    @Published private(set) var isScanningUninstall = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var uninstallFeedback: String?
    @Published private(set) var uninstallFeedbackKind: UninstallFeedbackKind = .info
    @Published var removeKeychainCredentials = true
    @Published var removeApplication = true

    /// 当前卸载扫描任务及其代次。
    ///
    /// 弹窗取消后会重新开始扫描；旧任务即使晚到也不能覆盖新结果或清除
    /// 新扫描的加载态，因此写回前必须比对代次。
    private var uninstallScanTask: Task<Void, Never>?
    private var uninstallScanGeneration = 0

    init(
        docsCapability: any GeneralSettingsDocsCapability,
        updateChannelCapability: any GeneralSettingsUpdateChannelCapability,
        diagnosticsCapability: any GeneralSettingsDiagnosticsCapability,
        storageCapability: any GeneralSettingsStorageCapability,
        uninstallCapability: any GeneralSettingsUninstallCapability
    ) {
        self.docsCapability = docsCapability
        self.updateChannelCapability = updateChannelCapability
        self.diagnosticsCapability = diagnosticsCapability
        self.storageCapability = storageCapability
        self.uninstallCapability = uninstallCapability
        refreshManuals()
        selectedUpdateChannel = updateChannelCapability.updateChannel
        refreshStorageUsage()
    }

    // MARK: - 派生状态

    var isUpdateChannelAvailable: Bool {
        updateChannelCapability.isUpdateChannelAvailable
    }

    var isDiagnosticsAvailable: Bool {
        diagnosticsCapability.isDiagnosticsAvailable
    }

    var isUninstallAvailable: Bool {
        uninstallCapability.isUninstallAvailable
    }

    var isStorageAvailable: Bool {
        storageCapability.isStorageAvailable
    }

    var storageSizeDescription: String {
        guard isStorageAvailable else { return "存储服务暂不可用" }
        guard let storageSizeInBytes else { return "正在计算…" }
        return ByteCountFormatter.string(fromByteCount: storageSizeInBytes, countStyle: .file)
    }

    /// 说明书条目是否变化后由 Observer 调用来刷新。
    func refreshManuals() {
        manuals = docsCapability.manuals
    }

    func refreshStorageUsage() {
        storageSizeInBytes = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            storageSizeInBytes = await storageCapability.storageSizeInBytes()
        }
    }

    // MARK: - 用户意图

    func openStorageDirectory() {
        storageCapability.openStorageDirectory()
    }

    /// 检查更新：广播 `checkForUpdates` 通知，由宿主（如 Sparkle 更新插件）消费。
    func checkForUpdates() {
        NotificationCenter.default.post(
            name: Notification.Name("checkForUpdates"),
            object: nil
        )
    }

    func exportDiagnostics() {
        guard isDiagnosticsAvailable else {
            diagnosticsFeedback = "日志服务暂不可用。"
            return
        }

        isExportingDiagnostics = true
        diagnosticsFeedback = nil

        Task { @MainActor in
            defer { isExportingDiagnostics = false }

            do {
                let archive = try await diagnosticsCapability.makeDiagnosticsArchive()
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

                try Self.installDiagnosticsArchive(from: archive.url, to: destination)
                diagnosticsFeedback = "日志已导出：\(destination.lastPathComponent)"
            } catch {
                diagnosticsFeedback = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    /// 把诊断 archive 安装到用户选择的位置。
    ///
    /// 先在同目录复制出临时文件，确认写入成功后才替换目标。复制阶段（空间不足、
    /// I/O 错误）失败时目标文件完全没被触碰；替换阶段失败则把原文件移回原位。
    /// 不能先 `removeItem(destination)` 再 copy——那会在失败时直接丢掉用户数据（#997）。
    static func installDiagnosticsArchive(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        let staging = directory.appendingPathComponent(".lumi-diagnostics-\(UUID().uuidString).zip")
        defer { try? fileManager.removeItem(at: staging) }

        try fileManager.copyItem(at: source, to: staging)

        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: staging, to: destination)
            return
        }

        let backup = directory.appendingPathComponent(".lumi-diagnostics-backup-\(UUID().uuidString).zip")
        try fileManager.moveItem(at: destination, to: backup)
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            // 替换失败时回滚，失败路径同样不允许丢数据。
            try? fileManager.moveItem(at: backup, to: destination)
            throw error
        }
        try? fileManager.removeItem(at: backup)
    }

    func beginUninstall() {
        guard isUninstallAvailable else {
            uninstallFeedback = "卸载服务暂不可用。"
            uninstallFeedbackKind = .warning
            return
        }

        uninstallScanTask?.cancel()
        uninstallScanTask = nil
        uninstallScanGeneration &+= 1
        let generation = uninstallScanGeneration

        uninstallFeedback = nil
        uninstallFeedbackKind = .info
        removeKeychainCredentials = true
        removeApplication = true
        uninstallScan = nil
        isScanningUninstall = true

        uninstallScanTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let scan = await uninstallCapability.scanUninstall()
            guard uninstallScanGeneration == generation else { return }
            uninstallScan = scan
            isScanningUninstall = false
            uninstallScanTask = nil
        }
    }

    /// 关闭卸载弹窗时调用：取消在途扫描并使其结果失效。
    ///
    /// 只清理由本代扫描产生的状态；重新打开弹窗会从 `beginUninstall()` 开始新一轮。
    func cancelUninstallScan() {
        uninstallScanTask?.cancel()
        uninstallScanTask = nil
        uninstallScanGeneration &+= 1
        isScanningUninstall = false
        uninstallScan = nil
    }

    func performUninstall() {
        guard isUninstallAvailable else {
            uninstallFeedback = "卸载服务暂不可用。"
            uninstallFeedbackKind = .warning
            return
        }

        isUninstalling = true
        uninstallFeedback = nil
        uninstallFeedbackKind = .info

        // 关闭确认弹窗，隐藏设置窗口，切换到与主窗口解耦的独立卸载浮层。
        // 内核停止后设置窗口可能暂时失去内容，浮层负责承载后续所有阶段。
        NSApp.windows.forEach { $0.orderOut(nil) }
        UninstallOverlayWindowController.shared.show(
            phase: .running,
            onExit: { [weak self] in self?.terminateAfterUninstall() },
            onClose: {
                UninstallOverlayWindowController.shared.close()
                self.restoreApplicationAfterUninstallFailure()
            }
        )
        NotificationCenter.default.post(name: .lumiWillUninstall, object: nil)

        Task { @MainActor in
            defer { isUninstalling = false }
            do {
                await uninstallCapability.prepareForUninstall()
                let result = try await uninstallCapability.uninstall(options: UninstallOptions(
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
    private func terminateAfterUninstall() {
        NSApp.hide(nil)
        NSApp.terminate(nil)

        // 如果某个 AppKit/第三方组件延迟了终止请求，短暂兜底后强制结束。
        // 卸载前内核已经完成 shutdown，数据清理也已经完成。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if NSApp.isRunning {
                exit(EXIT_SUCCESS)
            }
        }
    }

    private func restoreApplicationAfterUninstallFailure() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
    }
}
