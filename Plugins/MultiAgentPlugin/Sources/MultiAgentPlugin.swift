import LumiCoreKit
import SwiftUI
import os

/// 多智能体插件：创建和收集子智能体工具。
public enum MultiAgentPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
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
            SpawnAgentTool(),
            CollectAgentsTool(),
        ]
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
