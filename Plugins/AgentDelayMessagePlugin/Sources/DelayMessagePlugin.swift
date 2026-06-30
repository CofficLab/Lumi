import LumiCoreKit
import SwiftUI
import os

/// 延时消息插件：在未来某个时刻自动恢复对话。
public enum DelayMessagePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "clock.badge"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.delay-message")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.delay-message",
        displayName: LumiPluginLocalization.string("Delay Message", bundle: .module),
        description: LumiPluginLocalization.string("Schedule delayed messages to resume conversations automatically.", bundle: .module),
        order: 98
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [DelayMessageTool()]
    }

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .general
        )
    }

}
