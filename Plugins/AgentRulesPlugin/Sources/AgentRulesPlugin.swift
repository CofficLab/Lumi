import LumiCoreKit

public enum AgentRulesPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "doc.text"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.agent-rules",
        displayName: LumiPluginLocalization.string("Agent Rules", bundle: .module),
        description: LumiPluginLocalization.string("Manage rule documents in .agent/rules directory", bundle: .module),
        order: 50
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [AgentRulesChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            CreateAgentRuleTool(),
            ListAgentRulesTool()
        ]
    }
}
