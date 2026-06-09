import Foundation
import LumiCoreKit

@MainActor
public extension RAGPlugin {
    static func bootstrapRuntime(
        currentProjectPath: @escaping @Sendable () -> String,
        currentProjectName: @escaping @Sendable () -> String = { "" },
        recentProjects: @escaping @Sendable () -> [RAGRuntimeProject] = { [] }
    ) {
        let ragDirectory = LumiCore.pluginDataDirectory(for: "RAG")
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
        RAGPluginRuntime.currentProjectProvider = {
            let path = currentProjectPath().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            let name = currentProjectName().trimmingCharacters(in: .whitespacesAndNewlines)
            return RAGRuntimeProject(
                name: name.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : name,
                path: path
            )
        }
        RAGPluginRuntime.recentProjectsProvider = recentProjects
    }
}
