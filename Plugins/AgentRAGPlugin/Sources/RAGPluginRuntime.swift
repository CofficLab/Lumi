import Foundation

public struct RAGRuntimeProject: Sendable, Equatable {
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public enum RAGPluginRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: @Sendable () -> URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi-RAGPlugin", isDirectory: true)
    }
    nonisolated(unsafe) public static var currentProjectProvider: @Sendable () -> RAGRuntimeProject? = { nil }
    nonisolated(unsafe) public static var recentProjectsProvider: @Sendable () -> [RAGRuntimeProject] = { [] }

    public static var currentProjectPath: String {
        currentProjectProvider()?.path ?? ""
    }

    public static var currentProjectName: String {
        currentProjectProvider()?.name ?? ""
    }
}
