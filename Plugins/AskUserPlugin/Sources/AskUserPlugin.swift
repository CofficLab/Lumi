import AgentToolKit
import LumiCoreKit

/// 用户询问插件
///
/// 提供 ask_user 工具，让 LLM 可以向用户提问并等待回答。
/// 支持是/否选择、多选项选择和自由文本输入。
public enum AskUserPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "questionmark.circle.fill"

    public static let info = LumiPluginInfo(
        id: "plugin-ask-user",
        displayName: LumiPluginLocalization.string("用户询问插件", bundle: .module),
        description: LumiPluginLocalization.string("提供 ask_user 工具，让 LLM 可以向用户提问并等待回答", bundle: .module),
        order: 100
    )

    @MainActor
    private static var didConfigureRenderer = false

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [AskUserTool().asLumiAgentTool()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        if !didConfigureRenderer {
            didConfigureRenderer = true
            ToolCallRowRendererRegistry.shared.register(AskUserRowRenderer())
        }
        return []
    }
}
