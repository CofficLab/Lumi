import LumiCoreKit
import SwiftUI

public enum CodeReviewPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "checklist"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.code-review",
        displayName: LumiPluginLocalization.string("Code Review", bundle: .module),
        description: LumiPluginLocalization.string("Reviews current Git changes and reports actionable issues.", bundle: .module),
        order: 17
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [RunReviewTool()]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(CodeReviewAboutView())
    }
}
