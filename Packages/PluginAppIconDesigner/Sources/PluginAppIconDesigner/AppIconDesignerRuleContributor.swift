import ProviderAgentRules

/// App Icon Designer 插件贡献的 Agent 规则。
public struct AppIconDesignerRuleContributor: AgentRuleContributing {
    public let providerID: String

    public init(providerID: String = "com.coffic.lumi.plugin.app-icon-designer") {
        self.providerID = providerID
    }

    public var allRules: [AgentRuleDefinition] {
        [
            AgentRuleDefinition(
                id: "app-icon-designer-workflow",
                title: "App Icon Designer Workflow",
                description: "Use the App Icon Designer workflow for app icon creation and revision tasks.",
                content: """
                When the task involves designing or revising an app icon, use the App Icon Designer tools and keep the icon document as the source of truth. Prefer a complete vector/layer structure over a flattened preview, preview the result before exporting, run the icon document lint check, and export only after the document passes validation. Preserve the project scope unless the user explicitly asks for a different scope.
                """
            ),
        ]
    }
}
