import Foundation
import KernelLumi

/// 工具共享助手（参数解析、路径校验、本地化）。
enum RecordingToolSupport {

    /// 默认下载目录（对齐 `DownloadPlugin.defaultDownloadDirectory`）。
    static func defaultDownloadDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// 解析并校验输出目录（沙盒），返回已校验的绝对路径。
    static func resolveOutputDirectory(_ raw: String?, kernel: KernelLumi) throws -> URL {
        let path = (raw?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty) ?? defaultDownloadDirectory().path
        let expanded = (path as NSString).expandingTildeInPath
        guard kernel.isPathAllowed(expanded) else {
            throw RecordingError.pathDenied(expanded)
        }
        return URL(fileURLWithPath: expanded)
    }

    /// 把 `RecordingError` 转成对 LLM/用户友好的双语文案，并按需打开系统设置。
    @MainActor
    static func describe(_ error: RecordingError, kernel: KernelLumi) -> String {
        let en = error.errorDescription ?? "Unknown error"
        let zh: String
        switch error {
        case .permissionDenied:
            RecordingPermissionService.openScreenRecordingSettings()
            zh = "需要「屏幕录制」权限。已在系统设置打开对应面板，请开启 Lumi 的开关后重试。"
        case .microphonePermissionDenied:
            RecordingPermissionService.openMicrophoneSettings()
            zh = "需要「麦克风」权限才能录制解说。已在系统设置打开对应面板，请开启后重试。"
        case .noSuchWindow(let app):
            zh = "没有找到「\(app)」的可见窗口，请确认 app 已运行。"
        case .targetIsLumi:
            zh = "已拒绝：不能录制 Lumi 自身。"
        case .alreadyRecording(let desc):
            zh = "当前已经在录制（\(desc)），请先停止再开始新的录制。"
        case .notRecording:
            zh = "当前没有正在进行的录制。"
        case .encodingFailed(let detail):
            zh = "编码失败：\(detail)"
        case .diskFull:
            zh = "磁盘空间不足，无法保存录制。"
        case .pathDenied(let path):
            zh = "路径「\(path)」不在允许的目录范围内。"
        case .cancelled:
            zh = "录制已取消。"
        }
        return ScreenRecorderLocalization.localized(kernel.language, en: en, zh: zh)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
