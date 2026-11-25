import Foundation
import KernelCore
import LumiFactory
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
import PluginToolLLMProvider
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
    public static func makeKernel() async throws -> KernelCoreContainer {
        try await KernelFactory.makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: ACPPluginFactory()
        )
    }

    /// 启动 ACP 的 stdio JSON-RPC 服务。
    ///
    /// 入口由 LumiACP app 和历史 ACPBootstrap 共用，确保两个发布形态
    /// 不会因为各自维护一份启动逻辑而产生行为差异。
    ///
    /// - Note: 本方法**不接管主 runloop**——内核装配走共享流水线只能在主线程异步
    /// 进行，而 `RunLoop.run()` 禁止在异步上下文调用。启动完成后由调用方常驻主
    /// runloop 驱动 stdio 事件，见 `LumiACPExecutable/main.swift`。
    public static func runACPServer() async throws {
        setenv("LUMI_ACP_HEADLESS", "1", 1)

        let kernel = try await makeKernel()
        guard let plugin = kernel.resolvePlugin(id: "acp") as? PluginACP else {
            throw ACPBootstrapError.pluginNotFound
        }

        plugin.onEOF = { exit(0) }
        try plugin.startACPServer(transport: StdioTransport())
    }
}

// 显式声明 Equatable：无关联值的枚举会免费获得它，加上 kernelBootFailed 后必须自己要求，
// 否则既有测试里的 `error == .pluginNotFound` 编不过。
public enum ACPBootstrapError: Error, LocalizedError, CustomStringConvertible, Equatable {
    case pluginNotFound
    /// 共享装配流水线未能交付内核（磁盘预检、基线 Provider、插件 boot 失败等）。
    case kernelBootFailed(BootstrapFailureReport)

    public var description: String {
        switch self {
        case .pluginNotFound:
            "plugin 'acp' not found"
        case .kernelBootFailed(let report):
            "kernel boot failed: \(report.technicalDetail)"
        }
    }

    public var errorDescription: String? {
        description
    }
}

/// ACP headless 专用插件目录。
@MainActor
public struct ACPPluginFactory: PluginFactory {
    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
        var plugins: [any SuperPlugin] = []
        if let storage = StorageSuperPlugin.makeIfAvailable() {
            plugins.append(storage)
        }
        plugins += [
            CommandPlugin(),
            ToastSuperPlugin(),
            PluginLLMManager(),
            PluginToolManager(),
            AgentLoopRetryPlugin(),
            MessageSenderPlugin(),
            AgentRulesPlugin(),
            AgentTempStoragePlugin(),
            AgentPlanStoragePlugin(),
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            // 上下文压缩插件必须早于 AgentLoop 启动：两者 order 相同，Kernel 以
            // 数组顺序决定先后，若 AgentLoop 先启动就会捕获启动阶段的降级
            // 上下文 Provider，导致每一轮都绕过压缩（#883）。
            LLMContextPlugin(),
            PluginAgentLoop(),
            ConversationStatePlugin(),
            ConversationPendingMessagePlugin(),
            ConversationTitlePlugin(),
            AskUserPlugin(),
            FileLogPlugin(),
            SkillPlugin(),
            PluginPluginManager(),
            LLMProviderSettingsPlugin(),
            // 「用对话添加 LLM 供应商」：工具 + 提案卡片。
            // order=120，必须晚于上面的供应商设置插件（order=100）。
            PluginLLMProviderToolPlugin(),
            ModelSelectorPlugin(),
            MCPPlugin(),
            WebFetchPlugin(),
            WebSearchPlugin(),
            DocxReadPlugin(),
            TerminalPlugin(),
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
            MLXProviderPlugin(),
        ]
        return plugins
    }
}
