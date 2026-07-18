import Foundation

public struct LumiConversationContextUsage: Sendable, Equatable {
    public let currentTokens: Int
    public let limit: Int

    public init(currentTokens: Int, limit: Int) {
        self.currentTokens = currentTokens
        self.limit = limit
    }

    public var label: String {
        let current = Self.formatToken(currentTokens)
        guard limit > 0 else { return current }
        return "\(current)/\(Self.formatToken(limit))"
    }

    public static func formatToken(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        return String(format: "%.1fk", Double(value) / 1000.0)
    }
}

public enum LumiConversationContextCalculator {
    public static func usage(
        messages: [LumiChatMessage],
        providerID: String?,
        modelName: String?,
        providerInfos: [LumiLLMProviderInfo]
    ) -> LumiConversationContextUsage {
        let currentTokens = currentContextTokens(from: messages)
        let limit = contextLimit(
            providerID: providerID,
            modelName: modelName,
            providerInfos: providerInfos
        )
        return LumiConversationContextUsage(currentTokens: currentTokens, limit: limit)
    }

    public static func currentContextTokens(from messages: [LumiChatMessage]) -> Int {
        let timeline = messages.filter { $0.role != .status && $0.role != .error }
        guard let lastAssistantIndex = timeline.lastIndex(where: { $0.role == .assistant }) else {
            return 0
        }

        let baseContext = timeline[lastAssistantIndex].inputTokenCount ?? 0
        guard lastAssistantIndex < timeline.index(before: timeline.endIndex) else {
            return baseContext
        }

        let newTokens = timeline[timeline.index(after: lastAssistantIndex)...]
            .filter { $0.role == .user }
            .reduce(0) { total, message in
                total + estimatedTokenCount(for: message.content)
            }

        return baseContext + newTokens
    }

    public static func contextLimit(
        providerID: String?,
        modelName: String?,
        providerInfos: [LumiLLMProviderInfo]
    ) -> Int {
        guard let providerID,
              let modelName,
              let providerLimit = providerInfos.first(where: { $0.id == providerID })?.contextWindowSizes[modelName],
              providerLimit > 0 else {
            return 0
        }
        return providerLimit
    }

    private static func estimatedTokenCount(for content: String) -> Int {
        content.count / 4
    }
}
