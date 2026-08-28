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
import PluginNetworkManager
import PluginDocxRead
import PluginHostsManager
import PluginIdleTime
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
import PluginMessageSender
import PluginMindMapDesigner
import PluginModelSelector
import PluginOcr
import PluginPluginManager
import PluginProjects
import PluginResumeDesigner
import PluginSettingGeneral
import PluginSkill
import PluginThemePack
import PluginToolbarSettings
import PluginVideoConverter
import PluginWebFetch
import PluginWebSearch
import PluginWhiteNoise

/// 产出各种插件的工厂协议。
///
/// 集中管理插件的构造；`KernelFactory.makeKernel` 通过它产出插件并
/// 用 `kernel.start(plugins:)` 启动。宿主可实现该协议覆盖插件列表。
@MainActor
public protocol PluginFactory {
    /// 产出要启动的全部插件。
    ///
    /// 各插件在 `onBoot` 中解析内核已有 Provider 并注册自己的贡献
    /// （如 SettingGeneralPlugin 注册「通用」入口、DevicePlugin 注册
    ///  「设备信息」入口与主内容、SettingsToolbarPlugin 注册工具栏设置按钮）。
    func makePlugins() -> [any SuperPlugin]
}
