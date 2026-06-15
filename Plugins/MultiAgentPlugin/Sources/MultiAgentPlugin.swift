import AgentToolKit
import LumiCoreKit
import SwiftUI
import os

/// 多智能体插件：创建和收集子智能体工具。
public enum MultiAgentPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "person.3.fill"
    public static let verbose: Bool = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.multi-agent")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.multi-agent",
        displayName: LumiPluginLocalization.string("Multi Agent", bundle: .module),
        description: LumiPluginLocalization.string("Spawn parallel sub-agents with independent LLM providers and models", bundle: .module),
        order: 88
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            SpawnAgentTool().asLumiAgentTool(),
            CollectAgentsTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "person.3.fill", title: "Multi Agent", description: "Spawn parallel sub-agents with independent LLM providers and models"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Multi Agent into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Multi Agent in plugin settings",
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
