import LumiCoreKit
import SwiftUI

public enum ModelSelectorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "globe"

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
}
