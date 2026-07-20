import Foundation
import LumiCoreAgentTool
import LumiCoreChat
import LumiCoreLayout
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiCoreProject
import LumiCoreStorage
import LumiKernel

// MARK: - LumiCoreProviding extension for makePluginContext
//
// 为 LumiCoreProviding 添加便捷构造 LumiPluginContext 的方法。
// 旧 LumiCoreKit 中由 LumiCoreCompat.swift 提供,迁入 LumiFactory (因为依赖 LumiCoreChat)。

extension LumiCoreProviding {
    /// 创建 LumiPluginContext（兼容旧版 API）
    func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil,
        additionalDependencies: (inout LumiPluginDependencies) -> Void = { _ in }
    ) -> LumiPluginContext {
        let lumiCore: any LumiCoreAccessing = self
        var dependencies = LumiPluginDependencies()

        if let chat = lumiCore.resolveService((any LumiChatServicing).self) {
            dependencies.register((any LumiChatServicing).self, chat)
        }
        if let toolService = lumiCore.resolveService((any LumiToolServicing).self) {
            dependencies.register((any LumiToolServicing).self, toolService)
        }
        if let providerSettings = lumiCore.resolveService((any LumiLLMProviderSettingsContributing).self) {
            dependencies.register((any LumiLLMProviderSettingsContributing).self, providerSettings)
        }

        additionalDependencies(&dependencies)

        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: dependencies,
            lumiCore: lumiCore
        )
    }
}
