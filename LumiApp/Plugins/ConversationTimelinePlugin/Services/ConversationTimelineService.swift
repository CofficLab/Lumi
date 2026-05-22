import Foundation
import ToolKit
import LLMKit

/// 对话时间线的数据整理和统计逻辑。
struct ConversationTimelineService {
    struct Summary {
        let messageCount: Int
        let currentContextTokens: Int
    }

    func timelineItems(from messages: [ChatMessage]) -> [MessageTimelineItem] {
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

    func summary(from messages: [ChatMessage]) -> Summary {
        Summary(
            messageCount: messages.count,
            currentContextTokens: currentContextTokens(from: timelineItems(from: messages))
        )
    }

    func currentContextTokens(from items: [MessageTimelineItem]) -> Int {
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

    func contextLimit(providerId: String, model: String, providers: [LLMProviderInfo]) -> Int {
        providers.first(where: { $0.id == providerId })?.contextWindowSizes[model] ?? 0
    }

    func formatToken(_ value: Int) -> String {
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
