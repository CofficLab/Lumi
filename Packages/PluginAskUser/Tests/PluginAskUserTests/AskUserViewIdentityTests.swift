import Foundation
import Testing
import KitAgentTool
import ProviderAgentLoop

@testable import PluginAskUser

/// 回归 #483：ask_user 问题卡片的 SwiftUI 视图身份必须区分会话。
///
/// `AskUserChatSectionView` 用 `.id(...)` 决定 `AskUserPendingView` 的实例身份，
/// 而该视图把草稿 `answer` 与已提交标记 `responded` 存在 `@State` 里。同一个
/// `toolCallID`（如 `call_0`）在不同会话里都合法：若 `.id` 只用 `toolCallID`，
/// 从会话 A 切到 B 时身份不变，SwiftUI 复用旧实例的 `@State`，B 的卡片继承 A 的
/// 未发送草稿，甚至继承 A 的 `responded=true` 而错误禁用 B 的输入。
///
/// 修复把会话 ID 纳入 `viewIdentity`。这里锁定身份计算的不变量：跨会话必须不同、
/// 同会话同 tool call 必须稳定（重新 synchronize 不清草稿）、同会话不同 tool call
/// 必须不同（新问题重置状态）。
@Suite("AskUser 视图身份跨会话隔离")
struct AskUserViewIdentityTests {

    private func makeInteraction(
        conversationID: UUID,
        toolCallID: String
    ) -> AskUserPendingInteraction {
        let response = AskUserPendingResponse(
            toolCallId: "ask_user",
            question: "继续吗?",
            options: [],
            mode: "free_text",
            conversationId: "",
            verbosity: "standard"
        )
        return AskUserPendingInteraction(
            response: response,
            toolCallID: toolCallID,
            conversationID: conversationID,
            initialAnswer: nil
        )
    }

    @Test("同一 toolCallID 在不同会话必须产生不同视图身份，不得复用 @State")
    func sameToolCallIDAcrossConversationsHasDistinctViewIdentity() {
        let interactionA = makeInteraction(conversationID: UUID(), toolCallID: "call_0")
        let interactionB = makeInteraction(conversationID: UUID(), toolCallID: "call_0")
        // 原 bug：.id 只用 toolCallID，A→B 身份不变，answer/responded 被复用。
        #expect(interactionA.viewIdentity != interactionB.viewIdentity)
    }

    @Test("同一会话同一 toolCallID 的视图身份稳定，重新 synchronize 不清草稿")
    func sameConversationAndToolCallIDKeepsStableViewIdentity() {
        let conversationID = UUID()
        let first = makeInteraction(conversationID: conversationID, toolCallID: "call_0")
        let second = makeInteraction(conversationID: conversationID, toolCallID: "call_0")
        #expect(first.viewIdentity == second.viewIdentity)
    }

    @Test("同一会话内不同 toolCallID 产生不同视图身份，新问题重置状态")
    func distinctToolCallIDInSameConversationHasDistinctViewIdentity() {
        let conversationID = UUID()
        let first = makeInteraction(conversationID: conversationID, toolCallID: "call_0")
        let second = makeInteraction(conversationID: conversationID, toolCallID: "call_1")
        #expect(first.viewIdentity != second.viewIdentity)
    }
}