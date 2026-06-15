import AgentToolKit
import LumiCoreKit
import SwiftUI
import os

/// 延时消息插件：在未来某个时刻自动恢复对话。
public enum DelayMessagePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
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
        [DelayMessageTool().asLumiAgentTool()]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "clock.badge", title: "Delay Message", description: "Schedule delayed messages to resume conversations automatically."),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Delay Message into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Delay Message in plugin settings",
                "The plugin registers its contributions when enabled",
                "Use the features provided in the Lumi workspace"
            ],
            tips: [
                "Toggle the plugin off if you do not need this feature",
                "Check plugin settings for additional options"
            ]
        )
    }

}
