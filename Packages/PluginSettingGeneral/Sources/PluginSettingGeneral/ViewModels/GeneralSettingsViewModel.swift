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
/// 经 `GeneralSettingsCapability` 收敛，View 只读取本 ViewModel。
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

    private let capability: any GeneralSettingsCapability

    // MARK: - Published State (供 View 展示)

    /// 所有提供了说明书的文档条目。
    @Published private(set) var manuals: [DocsEntry] = []

    /// 当前更新通道（默认稳定版）。
    @Published var selectedUpdateChannel: AppUpdateChannel = .stable {
        didSet {
            guard selectedUpdateChannel != oldValue else { return }
            capability.setUpdateChannel(selectedUpdateChannel)
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

    init(capability: any GeneralSettingsCapability) {
        self.capability = capability
        refreshManuals()
        selectedUpdateChannel = capability.updateChannel
    }

    // MARK: - 派生状态

    var isOnboardingAvailable: Bool {
        capability.isOnboardingAvailable
    }

    var isUpdateChannelAvailable: Bool {
        capability.isUpdateChannelAvailable
    }

    var isDiagnosticsAvailable: Bool {
        capability.isDiagnosticsAvailable
    }

    var isUninstallAvailable: Bool {
        capability.isUninstallAvailable
    }

    /// 说明书条目是否变化后由 Observer 调用来刷新。
    func refreshManuals() {
        manuals = capability.manuals
    }

    // MARK: - 用户意图

    func replayOnboarding() {
        capability.replayOnboarding()
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
                let archive = try await capability.makeDiagnosticsArchive()
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

    func beginUninstall() {
        guard isUninstallAvailable else {
            uninstallFeedback = "卸载服务暂不可用。"
            uninstallFeedbackKind = .warning
            return
        }

        uninstallFeedback = nil
        uninstallFeedbackKind = .info
        removeKeychainCredentials = true
        removeApplication = true
        uninstallScan = nil
        isScanningUninstall = true

        Task { @MainActor in
            uninstallScan = await capability.scanUninstall()
            isScanningUninstall = false
        }
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
                await capability.prepareForUninstall()
                let result = try await capability.uninstall(options: UninstallOptions(
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
