import AgentToolKit
import LumiCoreKit

public enum CodeReviewPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .development
    public static let iconName = "checklist"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.code-review",
        displayName: String(localized: "Code Review", bundle: .module),
        description: String(localized: "Reviews current Git changes and reports actionable issues.", bundle: .module),
        order: 17
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [RunReviewTool().asLumiAgentTool()]
    }
}
