import AgentRAGPlugin
import LumiCoreKit
import MemoryPlugin

@MainActor
public enum LumiPluginBootstrap {
    public static func configurePluginRuntimes(
        currentProjectPath: @escaping @Sendable () -> String,
        currentProjectName: @escaping @Sendable () -> String = { "" },
        recentProjects: @escaping @Sendable () -> [RAGRuntimeProject] = { [] }
    ) {
        MemoryPlugin.bootstrapFromLumiCoreIfNeeded()
        RAGPlugin.bootstrapRuntime(
            currentProjectPath: currentProjectPath,
            currentProjectName: currentProjectName,
            recentProjects: recentProjects
        )
    }
}
