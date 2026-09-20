import Foundation
import KernelCore
import PluginACP
import PluginAgentLoop
import PluginAgentLoopRetry
import PluginAgentPlanStorage
import PluginAgentRules
import PluginAgentTempStorage
import PluginAskUser
import PluginCommand
import PluginConversationManager
import PluginConversationPendingMessage
import PluginConversationState
import PluginConversationTitle
import PluginDocxRead
import PluginFileLog
import PluginLLMContext
import PluginLLMManager
import PluginLLMProviderAiRouter
import PluginLLMProviderAliyun
import PluginLLMProviderAnthropic
import PluginLLMProviderCodex
import PluginLLMProviderCommandCode
import PluginLLMProviderDeepSeek
import PluginLLMProviderFeifeimiao
import PluginLLMProviderFlyMux
import PluginLLMProviderHappyCode
import PluginLLMProviderHyperAPI
import PluginLLMProviderKimiCode
import PluginLLMProviderLPgpt
import PluginLLMProviderMLX
import PluginLLMProviderMegaLLM
import PluginLLMProviderMiniMax
import PluginLLMProviderOpenAI
import PluginLLMProviderOpenCode
import PluginLLMProviderOpenRouter
import PluginLLMProviderSettings
import PluginLLMProviderStepFun
import PluginLLMProviderSublyx
import PluginLLMProviderTencent
import PluginLLMProviderXiaomi
import PluginLLMProviderXybbz
import PluginLLMProviderZhipu
import PluginMCP
import PluginMessageManager
import PluginMessageSender
import PluginModelSelector
import PluginPluginManager
import PluginSkill
import PluginStorage
import PluginToast
import PluginToolManager
import PluginWebFetch
import PluginWebSearch
import ProviderACP
import TerminalPlugin

/// ACP 专用的 Lumi 装配根。
///
/// ACP 与 GUI 共用 KernelCore、Provider 和功能插件，但只启动 headless
/// agent 所需的插件目录。宿主（LumiACPApp 或 ACPBootstrap）只依赖本工厂，
/// 不再各自维护一份 ACP 装配逻辑。
@MainActor
public enum FactoryLumiACP {
    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: ACPPluginFactory()
        )
    }

    /// 启动 ACP 的 stdio JSON-RPC 服务。
    ///
    /// 入口由 LumiACP app 和历史 ACPBootstrap 共用，确保两个发布形态
    /// 不会因为各自维护一份启动逻辑而产生行为差异。
    public static func runACPServer() throws {
        setenv("LUMI_ACP_HEADLESS", "1", 1)

        let kernel = try makeKernel()
        guard let plugin = kernel.resolvePlugin(id: "acp") as? PluginACP else {
            throw ACPBootstrapError.pluginNotFound
        }

        plugin.onEOF = { exit(0) }
        try plugin.startACPServer(transport: StdioTransport())
        RunLoop.main.run()
    }
}

public enum ACPBootstrapError: Error, CustomStringConvertible {
    case pluginNotFound

    public var description: String {
        switch self {
        case .pluginNotFound:
            "plugin 'acp' not found"
        }
    }
}

/// ACP headless 专用插件目录。
@MainActor
public struct ACPPluginFactory: PluginFactory {
    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
        [
            try! StorageSuperPlugin(),
            CommandPlugin(),
            ToastSuperPlugin(),
            PluginLLMManager(),
            PluginToolManager(),
            PluginAgentLoop(),
            AgentLoopRetryPlugin(),
            MessageSenderPlugin(),
            AgentRulesPlugin(),
            AgentTempStoragePlugin(),
            AgentPlanStoragePlugin(),
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            LLMContextPlugin(),
            ConversationStatePlugin(),
            ConversationPendingMessagePlugin(),
            ConversationTitlePlugin(),
            AskUserPlugin(),
            FileLogPlugin(),
            SkillPlugin(),
            PluginPluginManager(),
            LLMProviderSettingsPlugin(),
            ModelSelectorPlugin(),
            MCPPlugin(),
            WebFetchPlugin(),
            WebSearchPlugin(),
            DocxReadPlugin(),
            TerminalSuperPlugin(),
            PluginACP(),
            AiRouterProviderPlugin(),
            AliyunProviderPlugin(),
            AnthropicProviderPlugin(),
            DeepSeekProviderPlugin(),
            FeifeimiaoProviderPlugin(),
            FlyMuxProviderPlugin(),
            HappyCodeProviderPlugin(),
            HyperAPIProviderPlugin(),
            KimiCodeProviderPlugin(),
            LPgptProviderPlugin(),
            MegaLLMProviderPlugin(),
            MiniMaxProviderPlugin(),
            OpenAIProviderPlugin(),
            OpenCodeProviderPlugin(),
            CommandCodeProviderPlugin(),
            OpenRouterProviderPlugin(),
            StepFunProviderPlugin(),
            SublyxProviderPlugin(),
            TencentProviderPlugin(),
            XiaomiProviderPlugin(),
            XybbzProviderPlugin(),
            ZhipuProviderPlugin(),
            CodexLumiPlugin(),
            MLXProviderPlugin(),
        ]
    }
}
