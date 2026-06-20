import AgentRAGPlugin
import AgentRulesPlugin
import AskUserPlugin
import AutoTaskPlugin
import ConversationTitlePlugin
import FileLogPlugin
import GitPlugin
import GitHubPlugin
import IdleTimePlugin
import LLMAvailabilityPlugin
import LumiCoreKit
import MemoryPlugin
import ProjectIssueScannerPlugin

@MainActor
public enum LumiPluginBootstrap {
    public static func configurePluginRuntimes(
        currentProjectPath: @escaping @Sendable () -> String,
        currentProjectName: @escaping @Sendable () -> String = { "" },
        chatServiceProvider: (@MainActor () -> (any LumiChatServicing)?)? = nil,
        askUserResumer: (any LumiAskUserResuming)? = nil
    ) {
        MemoryPlugin.bootstrapFromLumiCoreIfNeeded()
        FileLogPlugin.bootstrapIfNeeded()
        AutoTaskPlugin.bootstrapFromLumiCoreIfNeeded()
        GitHubPlugin.bootstrapFromLumiCoreIfNeeded()
        IdleTimePlugin.bootstrapFromLumiCoreIfNeeded()
        ProjectIssueScannerPlugin.bootstrapFromLumiCoreIfNeeded()
        if let chatServiceProvider {
            AutoTaskPlugin.bootstrapTurnCheck(chatServiceProvider: chatServiceProvider)
            ConversationTitlePlugin.bootstrap(chatServiceProvider: chatServiceProvider)
            GitPlugin.bootstrap(chatServiceProvider: chatServiceProvider)
        }
        RAGPlugin.bootstrapRuntime()
        AgentRulesRuntime.currentProjectPathProvider = currentProjectPath
        if let askUserResumer {
            AskUserPlugin.configureAskUserResume(askUserResumer)
        }
    }

    /// 初始化 LLM 可用性检测：注入适配器并触发全量检测。
    ///
    /// 应在供应商注册完成后调用。
    public static func configureAvailabilityChecker(providers: [any LumiLLMProvider]) {
        LLMAvailabilityPlugin.bootstrap(providers: providers)
    }
}
