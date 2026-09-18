import Foundation
import KernelCore
import FactoryLumi

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
import PluginACP
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

// Tool plugins that agents commonly use
import PluginWebFetch
import PluginWebSearch
import PluginDocxRead
import TerminalPlugin

// LLM providers — keep all so any user-configured provider works
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
import PluginLLMProviderMLX

/// Headless ACP 专用插件目录：只包含 ACP turn 执行链必须的插件，
/// 剔除所有 UI / 设计器 / 编辑器 / open-in 等桌面插件。
///
/// 与 `DefaultPluginFactory` 的差异：
/// - 不实例化 UI 插件（聊天面板、工具栏、活动栏、设计器、编辑器等），
///   链接器可 dead-strip 这些插件的代码，显著减小二进制体积。
/// - Provider 层仍由 `DefaultProviderFactory` 完整注册，确保核心插件
///   onBoot 时解析 provider 不会失败。
@MainActor
public struct ACPPluginFactory: PluginFactory {
    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
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

            // LLM providers（全部保留，用户可能配置任意一个）
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
