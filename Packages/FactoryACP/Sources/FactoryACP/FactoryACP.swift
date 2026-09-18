import Foundation
import FactoryLumi
import KernelCore
import ProviderACP
import PluginACP

// Core plugins
import PluginStorage
import PluginCommand
import PluginToast
import PluginLLMManager
import PluginToolManager
import PluginAgentLoop
import PluginAgentLoopRetry
import PluginMessageSender
import PluginConversationManager
import PluginMessageManager
import PluginLLMContext
import PluginConversationState
import PluginConversationPendingMessage
import PluginConversationTitle
import PluginAskUser
import PluginAgentRules
import PluginAgentTempStorage
import PluginAgentPlanStorage
import PluginFileLog
import PluginSkill
import PluginPluginManager
import PluginLLMProviderSettings
import PluginModelSelector
import PluginMCP

// Tool plugins
import PluginWebFetch
import PluginWebSearch
import PluginDocxRead
import TerminalPlugin

// LLM providers
import PluginLLMProviderAiRouter
import PluginLLMProviderAliyun
import PluginLLMProviderAnthropic
import PluginLLMProviderDeepSeek
import PluginLLMProviderFeifeimiao
import PluginLLMProviderFlyMux
import PluginLLMProviderHappyCode
import PluginLLMProviderHyperAPI
import PluginLLMProviderKimiCode
import PluginLLMProviderLPgpt
import PluginLLMProviderMegaLLM
import PluginLLMProviderMiniMax
import PluginLLMProviderOpenAI
import PluginLLMProviderOpenCode
import PluginLLMProviderCommandCode
import PluginLLMProviderOpenRouter
import PluginLLMProviderStepFun
import PluginLLMProviderSublyx
import PluginLLMProviderTencent
import PluginLLMProviderXiaomi
import PluginLLMProviderXybbz
import PluginLLMProviderZhipu
import PluginLLMProviderCodex

/// Headless ACP 专用 KernelCore 宿主工厂。
///
/// 与 `FactoryLumi` 的差异：使用 `ACPPluginFactory` 只启动 turn 执行链必须的插件，
/// 剔除 UI / 设计器 / 编辑器等桌面插件。Provider 层仍由 `DefaultProviderFactory` 完整注册。
@MainActor
public enum FactoryACP {
    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: ACPPluginFactory()
        )
    }
}

/// Headless ACP 专用插件目录：只包含 ACP turn 执行链必须的插件。
@MainActor
struct ACPPluginFactory: PluginFactory {
    func makePlugins() -> [any SuperPlugin] {
        [
            // 核心基础
            try! StorageSuperPlugin(),
            CommandPlugin(),
            ToastSuperPlugin(),

            // LLM / Agent loop / 工具
            PluginLLMManager(),
            PluginToolManager(),
            PluginAgentLoop(),
            AgentLoopRetryPlugin(),
            MessageSenderPlugin(),
            AgentRulesPlugin(),
            AgentTempStoragePlugin(),
            AgentPlanStoragePlugin(),

            // 会话 / 消息
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            LLMContextPlugin(),
            ConversationStatePlugin(),
            ConversationPendingMessagePlugin(),
            ConversationTitlePlugin(),

            // 能力
            AskUserPlugin(),
            FileLogPlugin(),
            SkillPlugin(),
            PluginPluginManager(),
            LLMProviderSettingsPlugin(),
            ModelSelectorPlugin(),
            MCPPlugin(),

            // 工具插件
            WebFetchPlugin(),
            WebSearchPlugin(),
            DocxReadPlugin(),
            TerminalSuperPlugin(),

            // ACP 本身
            PluginACP(),

            // LLM providers
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
        ]
    }
}
