import Foundation
import Testing
@testable import PluginConversationTimeline
import LumiCoreKit

@Test func modelDisplayTextUsesAvailableNonEmptyMetadata() async throws {
    #expect(makeTimelineItem(providerId: "openai", modelName: "gpt-4.1").modelDisplayText == "openai / gpt-4.1")
    #expect(makeTimelineItem(providerId: "  anthropic  ", modelName: nil).modelDisplayText == "anthropic")
    #expect(makeTimelineItem(providerId: nil, modelName: "\nclaude-sonnet\n").modelDisplayText == "claude-sonnet")
    #expect(makeTimelineItem(providerId: "  ", modelName: "\n").modelDisplayText == nil)
}

private func makeTimelineItem(providerId: String?, modelName: String?) -> MessageTimelineItem {
    MessageTimelineItem(
        id: UUID(),
        role: .assistant,
        content: "Hello",
        timestamp: Date(timeIntervalSince1970: 0),
        hasToolCalls: false,
        isError: false,
        providerId: providerId,
        modelName: modelName,
        inputTokens: nil,
        outputTokens: nil
    )
}
