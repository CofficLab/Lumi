import AgentToolKit
import Foundation
import LumiCoreKit

/// 用户询问插件
///
/// 提供 ask_user 工具，让 LLM 可以向用户提问并等待回答。
/// 支持是/否选择、多选项选择和自由文本输入。
public enum AskUserPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "plugin-ask-user",
        displayName: LumiPluginLocalization.string("用户询问插件", bundle: .module),
        description: LumiPluginLocalization.string("提供 ask_user 工具，让 LLM 可以向用户提问并等待回答", bundle: .module),
        order: 100,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "questionmark.circle.fill",
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

    @MainActor
    public static func configureAskUserResume(_ resumer: any LumiAskUserResuming) {
        AskUserBridge.shared.resumeHandler = { conversationId, toolCallId, answer in
            guard let conversationID = UUID(uuidString: conversationId) else { return }
            Task { await resumer.resumeAfterAskUser(conversationID: conversationID, toolCallID: toolCallId, answer: answer) }
        }
    }
}
