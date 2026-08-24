import Foundation

/// 屏幕录制插件的运行时配置入口。
///
/// 在 `onBoot` 时由插件调用，缓存内核引用、注入存储目录，并触发崩溃恢复清理。
/// 架构对齐 `MindMapRuntime`。
@MainActor
public enum ScreenRecorderRuntime {
    /// 本插件的数据根目录（存放临时录制文件等）。
    public private(set) static var dataDirectory: URL = FileManager.default.temporaryDirectory

    /// 临时录制文件目录。
    public static var tempDirectory: URL {
        dataDirectory.appendingPathComponent("tmp", isDirectory: true)
    }

    /// 新版内核入口。新版不持有 `KernelLumi`，仅注入插件专属的数据目录。
    public static func configure(dataDirectory: URL) {
        Self.dataDirectory = dataDirectory
        purgeStaleTempFiles()
    }

    public static func reset() {
        Self.dataDirectory = FileManager.default.temporaryDirectory
    }

    private static func purgeStaleTempFiles() {
        // 崩溃恢复：清理上次可能残留的临时文件。
        RecordingFileWriter.purgeStaleTempFiles(in: Self.dataDirectory)
    }
}
