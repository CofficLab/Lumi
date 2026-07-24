import Foundation
import LumiKernel

public enum RAGPluginRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: @Sendable () -> URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi-ProjectRAGPlugin", isDirectory: true)
    }

    /// 内核引用，由 `ProjectRAGPlugin.onReady(kernel:)` 设置。
    @MainActor
    public static var kernel: LumiKernel?

    /// 当前项目路径，优先从 kernel 读取。
    @MainActor
    public static var currentProjectPath: String {
        if let path = kernel?.project?.currentProject?.path, !path.isEmpty {
            return path
        }

        return ""
    }

    /// 当前项目名称，优先从 kernel 读取。
    @MainActor
    public static var currentProjectName: String {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}
