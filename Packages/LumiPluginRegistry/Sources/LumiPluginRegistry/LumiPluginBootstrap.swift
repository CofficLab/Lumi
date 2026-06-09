import AgentRAGPlugin
import AgentRulesPlugin
import AutoTaskPlugin
import ConversationTitlePlugin
import FileLogPlugin
import GitPlugin
import GitHubInsightPlugin
import IdleTimePlugin
import LumiCoreKit
import MemoryPlugin
import ProjectIssueScannerPlugin

@MainActor
public enum LumiPluginBootstrap {
    public static func configurePluginRuntimes(
        currentProjectPath: @escaping @Sendable () -> String,
        currentProjectName: @escaping @Sendable () -> String = { "" },
        recentProjects: @escaping @Sendable () -> [RAGRuntimeProject] = { [] },
        chatServiceProvider: (@MainActor () -> (any LumiChatServicing)?)? = nil
    ) {
        MemoryPlugin.bootstrapFromLumiCoreIfNeeded()
        FileLogPlugin.bootstrapIfNeeded()
        AutoTaskPlugin.bootstrapFromLumiCoreIfNeeded()
        GitHubInsightPlugin.bootstrapFromLumiCoreIfNeeded()
        IdleTimePlugin.bootstrapFromLumiCoreIfNeeded()
        ProjectIssueScannerPlugin.bootstrapFromLumiCoreIfNeeded()
        if let chatServiceProvider {
            AutoTaskPlugin.bootstrapTurnCheck(chatServiceProvider: chatServiceProvider)
            ConversationTitlePlugin.bootstrap(chatServiceProvider: chatServiceProvider)
            GitPlugin.bootstrap(chatServiceProvider: chatServiceProvider)
        }
        RAGPlugin.bootstrapRuntime(
            currentProjectPath: currentProjectPath,
            currentProjectName: currentProjectName,
            recentProjects: recentProjects
        )
        AgentRulesRuntime.currentProjectPathProvider = currentProjectPath
    }
}
