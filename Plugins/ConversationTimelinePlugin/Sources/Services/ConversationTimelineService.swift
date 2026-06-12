import Foundation
import LumiCoreKit
import AgentToolKit
import LLMKit

/// 对话时间线的数据整理和统计逻辑。
public struct ConversationTimelineService {
    public struct Summary {
        public let messageCount: Int
        public let currentContextTokens: Int

        public init(messageCount: Int, currentContextTokens: Int) {
            self.messageCount = messageCount
            self.currentContextTokens = currentContextTokens
        }
    }

    public func timelineItems(from messages: [ChatMessage]) -> [MessageTimelineItem] {
        messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { message in
                MessageTimelineItem(
                    id: message.id,
                    role: message.role,
                    content: message.content,
                    timestamp: message.timestamp,
                    hasToolCalls: message.hasToolCalls,
                    isError: message.isError,
                    providerId: message.providerId,
                    modelName: message.modelName,
                    inputTokens: message.inputTokens,
                    outputTokens: message.outputTokens
                )
            }
    }

    public func summary(from messages: [ChatMessage]) -> Summary {
        Summary(
            messageCount: messages.count,
            currentContextTokens: currentContextTokens(from: timelineItems(from: messages))
        )
    }

    public func currentContextTokens(from items: [MessageTimelineItem]) -> Int {
        guard let lastAssistantIndex = items.lastIndex(where: { $0.role == .assistant }) else {
            return 0
        }

        let baseContext = items[lastAssistantIndex].inputTokens ?? 0
        guard lastAssistantIndex < items.index(before: items.endIndex) else {
            return baseContext
        }

        let newTokens = items[items.index(after: lastAssistantIndex)...]
            .filter { $0.role == .user }
            .reduce(0) { total, item in
                total + estimatedTokenCount(for: item.content)
            }

        return baseContext + newTokens
    }

    public func contextLimit(providerId: String, model: String, providers: [LLMProviderInfo]) -> Int {
        providers.first(where: { $0.id == providerId })?.contextWindowSizes[model] ?? 0
    }

    public func contextUsageRatio(currentTokens: Int, limit: Int) -> Double {
        guard limit > 0 else { return 0 }
        return Double(currentTokens) / Double(limit)
    }

    public func formatToken(_ value: Int) -> String {
        if value >= 1000 {
            let k = Double(value) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(value)"
    }

    private func estimatedTokenCount(for content: String) -> Int {
        content.count / 4
    }
}
