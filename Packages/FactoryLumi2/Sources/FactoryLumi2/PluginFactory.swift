import Foundation
import KernelCore
import PluginAgentRules
import PluginAgentTempStorage
import PluginAgentTurnNotification
import PluginAppIconDesigner
import PluginAppStorePromoDesigner
import PluginAskUser
import PluginCaffeinate
import PluginChatFileAttachment
import PluginChatPanel
import PluginChatScreenshot
import PluginConversationBehavior
import PluginConversationFork
import PluginConversationInput
import PluginConversationList
import PluginConversationManager
import PluginConversationMode
import PluginConversationNew
import PluginConversationPendingMessage
import PluginConversationTitle
import PluginDevice
import PluginDiskManager
import PluginDocxRead
import PluginHostsManager
import PluginIdleTime
import PluginLLMProviderAiRouter
import PluginLLMManager
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
import PluginLLMProviderOpenRouter
import PluginLLMProviderSettings
import PluginLLMProviderStepFun
import PluginLLMProviderSublyx
import PluginLLMProviderXiaomi
import PluginLLMProviderXybbz
import PluginLLMProviderZhipu
import PluginLogoCoffic
import PluginMemory
import PluginMessageList
import PluginMessageManager
import PluginMessageRenderer
import PluginAgentLoop
import PluginMessageSender
import PluginMindMapDesigner
import PluginModelSelector
import PluginOcr
import PluginOpenIn
import PluginPluginManager
import PluginProjects
import PluginResumeDesigner
import PluginSettingGeneral
import PluginSkill
import PluginThemePack
import PluginToolManager
import PluginToolbarSettings
import PluginVideoConverter
import PluginWebFetch
import PluginWebSearch
import PluginWhiteNoise

/// 默认 `PluginFactory` 实现：产出默认插件。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    /// 产出默认插件列表。
    public func makePlugins() -> [any SuperPlugin] {
        [
            CaffeinatePlugin(),
            SettingGeneralPlugin(),
            ProjectsPlugin(),
            DevicePlugin(),
            HostsManagerPlugin(),
            DiskManagerPlugin(),
            DocxReadPlugin(),
            WebFetchPlugin(),
            WebSearchPlugin(),
            AgentRulesPlugin(),
            AgentTempStoragePlugin(),
            OcrPlugin(),
            AppIconDesignerPlugin(),
            AppStorePromoDesignerPlugin(),
            MindMapDesignerPlugin(),
            ResumeDesignerPlugin(),
            LogoCofficPlugin(),
            SettingsToolbarPlugin(),
            ThemePackPlugin(),
            VideoConverterPlugin(),
            WhiteNoisePlugin(),
            IdleTimePlugin(),
            ChatPanelPlugin(),
            ChatFileAttachmentPlugin(),
            ChatScreenshotPlugin(),
            ConversationModePlugin(),
            ConversationVerbosityPlugin(),
            ConversationLanguagePlugin(),
            ConversationReasoningPlugin(),
            ConversationTitlePlugin(),
            ConversationPendingMessagePlugin(),
            ConversationForkPlugin(),
            AskUserPlugin(),
            OpenInPlugin(),
            AgentTurnNotificationPlugin(),
            SkillPlugin(),
            MemoryPlugin(),
            ModelSelectorPlugin(),
            MessageListPlugin(),
            MessageRendererPlugin(),
            ConversationInputPlugin(),
            ConversationListPlugin(),
            ConversationNewPlugin(),
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            PluginAgentLoop(),
            MessageSenderPlugin(),
            PluginPluginManager(),
            // LLM 供应商管理器：替换 ProviderFactory 预注册的默认实现，
            // 必须早于 PluginAgentLoop(order=8) 与各供应商插件(order=100)。
            PluginLLMManager(),
            // 工具管理器：替换默认 ToolManagerProviding 并注册内置工具，
            // 必须早于 PluginAgentLoop(order=8)。
            PluginToolManager(),
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
            OpenRouterProviderPlugin(),
            StepFunProviderPlugin(),
            SublyxProviderPlugin(),
            XiaomiProviderPlugin(),
            XybbzProviderPlugin(),
            ZhipuProviderPlugin(),
            LLMProviderSettingsPlugin(),
        ]
    }
}
