import Foundation
import KernelLumi

/// 一次带性能数据的消息样本，用于计算和展示流式速度。
struct ConversationSpeedSample: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let createdAt: Date
    let tokensPerSecond: Double
    let message: LumiChatMessage

    static func samples(from messages: [LumiChatMessage]) -> [ConversationSpeedSample] {
        messages
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { message -> (Date, Double, LumiChatMessage)? in
                guard let tps = message.conversationSpeedTokensPerSecond else { return nil }
                return (message.createdAt, tps, message)
            }
            .enumerated()
            .map { offset, sample in
                ConversationSpeedSample(
                    id: sample.2.id,
                    index: offset,
                    createdAt: sample.0,
                    tokensPerSecond: sample.1,
                    message: sample.2
                )
            }
    }

    static func averageTokensPerSecond(from samples: [ConversationSpeedSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0) { $0 + $1.tokensPerSecond }
        return total / Double(samples.count)
    }
}
