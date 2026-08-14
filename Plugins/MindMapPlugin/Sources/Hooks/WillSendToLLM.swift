import Foundation
import KernelLumi

/// 思维导图插件 willSendToLLM 钩子
///
/// 在 AgentTurnRunner 构造 LumiLLMRequest 之前被调用，将思维导图工具使用指南作为
/// system 消息注入到 messages 首位，引导 Agent 正确使用工具链。
@MainActor
public struct MindMapWillSendToLLMHook {
    public init() {}

    public func execute(
        kernel: KernelLumi,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }

        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: """
            Mind Map manages its own mind map library across two storage scopes. Every tool accepts an optional `scope` ('project' for the current project's `.lumi/mind-map` folder, or 'app' for the application data directory) and an optional `mapId`; when they are omitted, the currently selected mind map in the default scope is used. The default scope is 'project' when a project is open, otherwise 'app'. Call list_mind_maps to enumerate mind maps in either scope.

            For every user request to build a mind map: call create_mind_map once with a central topic as `rootText`, then grow the tree with add_child_node (pass an array of `texts` to add many siblings at once). Refine with update_node (text/note/color/collapsed), reorganize with move_node, and prune with delete_node. Node text is plain text — never reference remote resources, images, or external files. When the user provides an outline, prefer import_outline to build the whole tree in one call. Use export_mind_map (format 'markdown' or 'json') to surface the result as text. The canvas re-layouts automatically after each change, so the user sees updates live.
            """
        )

        return [guidance] + messages
    }
}
