import Foundation
import ProviderMessage
import Testing
@testable import PluginSubagent

/// 「子代理委托」时间线卡片的载荷与消息形态契约（#1313 Task 6）。
///
/// 卡片消息只给人看：带时间线标记与 renderKind，被
/// `MessageTimelineEvent.isTimelineEvent` 识别后不进 LLM 上下文。
@MainActor
@Suite("Subagent Timeline")
struct SubagentTimelineTests {

    @Test("载荷编解码往返无损")
    func payloadRoundTrip() throws {
        let payload = SubagentTimeline.Payload(
            label: "Research auth flow",
            parentConversationID: UUID(),
            childConversationID: UUID(),
            jobID: "job-1"
        )
        let metadata = SubagentTimeline.metadata(for: payload)
        let decoded = try #require(SubagentTimeline.decodePayload(from: metadata))
        #expect(decoded == payload)
    }

    @Test("载荷缺失或损坏返回 nil，调用方回退纯文本")
    func corruptedPayloadDecodesToNil() {
        #expect(SubagentTimeline.decodePayload(from: [:]) == nil)
        #expect(SubagentTimeline.decodePayload(from: [SubagentTimeline.payloadKey: "not-json"]) == nil)
    }

    @Test("卡片消息带时间线标记、renderKind 与首选渲染器")
    func messageShape() {
        let parentID = UUID()
        let turnID = UUID()
        let payload = SubagentTimeline.Payload(
            label: "Research",
            parentConversationID: UUID(),
            childConversationID: UUID(),
            jobID: "job-2"
        )
        let message = SubagentTimeline.message(
            conversationID: parentID,
            turnID: turnID,
            payload: payload
        )

        #expect(message.conversationID == parentID)
        #expect(message.role == .system)
        #expect(message.turnID == turnID)
        #expect(message.renderKind == MessageTimelineEvent.subagentDelegationRenderKind)
        #expect(message.preferredRendererID == SubagentTimeline.rendererID)
        #expect(MessageTimelineEvent.isTimelineEvent(message))
        #expect(message.content.contains("Research"))
    }
}