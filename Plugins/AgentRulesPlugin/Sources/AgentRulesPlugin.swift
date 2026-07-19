import LumiKernel

public enum AgentRulesPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.agent-rules",
        displayName: LumiPluginLocalization.string("Agent Rules", bundle: .module),
        description: LumiPluginLocalization.string("Manage rule documents in .agent/rules directory", bundle: .module),
        order: 50,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "doc.text",
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
