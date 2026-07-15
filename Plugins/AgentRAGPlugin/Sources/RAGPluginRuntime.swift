import Foundation
import LumiCoreKit

public enum RAGPluginRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: @Sendable () -> URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi-RAGPlugin", isDirectory: true)
    }

    /// 内核引用，由 bootstrapRuntime(context:) 设置。
    @MainActor
    public static var lumiCore: (any LumiCoreAccessing)?

    /// 当前项目路径，从内核 `lumiCore.projectState` 获取。
    @MainActor
    public static var currentProjectPath: String {
        lumiCore?.projectState?.currentProject?.path ?? ""
    }

    /// 当前项目名称，从路径推导。
    @MainActor
    public static var currentProjectName: String {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}
