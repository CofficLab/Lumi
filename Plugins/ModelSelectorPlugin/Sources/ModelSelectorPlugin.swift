import LumiChatKit
import Logging
import LumiCoreKit
import os
import SwiftUI

public enum ModelSelectorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "globe"
    public static let verbose: Bool = false
    public nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.model-selector",
        displayName: LumiPluginLocalization.string("Model Selector", bundle: .module),
        description: LumiPluginLocalization.string("Select LLM provider and model", bundle: .module),
        order: 82
    )

    @MainActor
    public static func chatSectionToolbarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarItem] {
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
    public static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
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
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        guard let chatService = context.resolve(LumiChatServicing.self) else {
            return []
        }
        return [SwitchModelTool(chatService: chatService)]
    }

    @MainActor
    public static func addSettingsTabs(context: LumiPluginContext) -> [LumiSettingsTabItem] {
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
