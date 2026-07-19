import AgentToolKit
import Foundation
import LumiCoreKit

/// 用户询问插件
///
/// 提供 ask_user 工具，让 LLM 可以向用户提问并等待回答。
/// 支持是/否选择、多选项选择和自由文本输入。
public enum AskUserPlugin: @preconcurrency LumiPlugin, LumiToolExecutionHook {

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
    public static func agentTools(lumiCore: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [AskUserTool().asLumiAgentTool()]
    }

    @MainActor
    public static func messageRenderers(lumiCore: any LumiCoreAccessing) -> [LumiMessageRendererItem] {
        if !didConfigureRenderer {
            didConfigureRenderer = true
            ToolCallRowRendererRegistry.shared.register(AskUserRowRenderer())
        }
        return []
    }

    // MARK: - Turn Finished Hook

    @MainActor
    public static func onTurnFinished(
        lumiCore: any LumiCoreAccessing,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        await AskUserResumeHook.handle(lumiCore: lumiCore, conversationID: conversationID, reason: reason)
    }

    // MARK: - LumiToolExecutionHook

    @MainActor
    public static func handleToolResult(
        toolName: String,
        result: String,
        conversationID: UUID
    ) async -> Bool {
        // 只处理 ask_user 工具
        guard toolName == AskUserTool.name else {
            return false
        }

        // 仅当结果处于 pending 状态时才需要暂停 Agent 循环等待用户输入。
        // 内核（ChatService）收到 true 后会设置状态提示并把 turn 结束原因设为
        // .awaitingUserResponse。
        return LumiAskUserMarkers.isPendingResponse(result)
    }
}
