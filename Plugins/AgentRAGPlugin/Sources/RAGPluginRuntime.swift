import Foundation
import LumiCoreKit

public enum RAGPluginRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: @Sendable () -> URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi-RAGPlugin", isDirectory: true)
    }

    /// 当前项目路径，从内核 `LumiCurrentProjectPathStore` 获取。
    public static var currentProjectPath: String {
        LumiCurrentProjectPathStore().currentProjectPath
    }

    /// 当前项目名称，从路径推导。
    public static var currentProjectName: String {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}
