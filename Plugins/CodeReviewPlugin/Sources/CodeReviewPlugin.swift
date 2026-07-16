import LumiCoreKit
import SwiftUI

public enum CodeReviewPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.code-review",
        displayName: LumiPluginLocalization.string("Code Review", bundle: .module),
        description: LumiPluginLocalization.string("Reviews current Git changes and reports actionable issues.", bundle: .module),
        order: 17,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "checklist",
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [RunReviewTool()]
    }

    @MainActor
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(CodeReviewAboutView())
    }
}
