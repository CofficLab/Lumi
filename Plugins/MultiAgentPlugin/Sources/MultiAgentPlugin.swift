import AgentToolKit
import LumiCoreKit
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
        displayName: String(localized: "Multi Agent", bundle: .module),
        description: String(localized: "Spawn parallel sub-agents with independent LLM providers and models", bundle: .module),
        order: 88
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            SpawnAgentTool().asLumiAgentTool(),
            CollectAgentsTool().asLumiAgentTool(),
        ]
    }
}
