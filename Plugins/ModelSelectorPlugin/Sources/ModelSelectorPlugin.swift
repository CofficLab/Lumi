
import LumiKernel
import LumiKernel
import os
import SwiftUI

public enum ModelSelectorPlugin: LumiPlugin {
    public static let verbose: Bool = true
    public nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.model-selector",
        displayName: LumiPluginLocalization.string("Model Selector", bundle: .module),
        description: LumiPluginLocalization.string("Select LLM provider and model", bundle: .module),
        order: 82,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "globe",
    )

    @MainActor
    public static func chatSectionToolbarItems(context: any LumiCoreAccessing) -> [LumiChatSectionToolbarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarItem(id: info.id, order: info.order, placement: .leading) {
                ModelProviderPicker(chatService: chatService)
            }
        ]
    }

    @MainActor
    public static func chatSectionToolbarBarItems(context: any LumiCoreAccessing) -> [LumiChatSectionToolbarBarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: "\(info.id).tps", order: info.order + 1) {
                CurrentModelTPSToolbarView(chatService: chatService)
            }
        ]
    }

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) throws -> [any LumiAgentTool] {
        // 工具要拿 `ChatService` 实例才能 `provider(forID:)`，所以这里强转。
        // LumiCoreKit 里的 `LumiChatServicing` 协议还没暴露 provider 字典——
        // 故意不暴露，避免其它子系统绕过 Provider 自己操作 Keychain。
        guard let chatService = context.resolve(LumiChatServicing.self) as? ChatService else {
            throw LumiPluginDependencyError.serviceUnavailable("ChatService")
        }
        return [
            SwitchModelTool(chatService: chatService),
            CheckModelAvailabilityTool(chatService: chatService),
            ListAvailableModelsTool(chatService: chatService),
        ]
    }

    @MainActor
    public static func addSettingsTabs(context: any LumiCoreAccessing) -> [LumiSettingsTabItem] {
        guard let chatService = context.resolve(LumiChatServicing.self) as? ChatService else {
            return []
        }

        let providerSettingsViews = context
            .resolve((any LumiLLMProviderSettingsContributing).self)?
            .llmProviderSettingsViews(context: context) ?? []

        return [
            LumiSettingsTabItem(
                id: "\(info.id).local",
                title: "本地供应商",
                systemImage: "cpu"
            ) {
                LocalProviderSettingsPage(
                    chatService: chatService,
                    providerSettingsViews: providerSettingsViews
                )
            },
            LumiSettingsTabItem(
                id: "\(info.id).remote",
                title: "云端供应商",
                systemImage: "network"
            ) {
                RemoteProviderSettingsPage(
                    chatService: chatService,
                    providerSettingsViews: providerSettingsViews
                )
            },
        ]
    }
}
