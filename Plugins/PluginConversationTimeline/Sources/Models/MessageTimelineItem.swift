import Foundation
import LumiCoreKit
import AgentToolKit

/// 用于时间线展示的轻量数据结构，从 `ChatMessage` 映射而来
public struct MessageTimelineItem: Identifiable {
    public let id: UUID
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    public let hasToolCalls: Bool
    public let isError: Bool
    public let providerId: String?
    public let modelName: String?
    public let inputTokens: Int?
    public let outputTokens: Int?

    var modelDisplayText: String? {
        let parts = [providerId, modelName].compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " / ")
    }
}
