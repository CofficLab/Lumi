import Foundation
import KernelLumi

/// 屏幕录制插件的运行时配置入口。
///
/// 在 `onBoot` 时由插件调用，缓存内核引用、注入存储目录，并触发崩溃恢复清理。
/// 架构对齐 `MindMapRuntime`。
@MainActor
public enum ScreenRecorderRuntime {
    /// 当前内核引用（弱持有，避免循环）。
    public private(set) static var kernel: KernelLumi?

    /// 本插件的数据根目录（存放临时录制文件等）。
    public private(set) static var dataDirectory: URL = FileManager.default.temporaryDirectory

    /// 临时录制文件目录。
    public static var tempDirectory: URL {
        dataDirectory.appendingPathComponent("tmp", isDirectory: true)
    }

    public static func configure(kernel: KernelLumi) {
        Self.kernel = kernel
        if let storage = kernel.storage {
            Self.dataDirectory = storage.pluginDataDirectory(for: "ScreenRecorder")
        }
        purgeStaleTempFiles()
    }

    /// 新版内核入口。新版不持有 `KernelLumi`，仅注入插件专属的数据目录。
    public static func configure(dataDirectory: URL) {
        Self.kernel = nil
        Self.dataDirectory = dataDirectory
        purgeStaleTempFiles()
    }

    public static func reset() {
        Self.kernel = nil
        Self.dataDirectory = FileManager.default.temporaryDirectory
    }

    private static func purgeStaleTempFiles() {
        // 崩溃恢复：清理上次可能残留的临时文件。
        RecordingFileWriter.purgeStaleTempFiles(in: Self.dataDirectory)
    }
}
