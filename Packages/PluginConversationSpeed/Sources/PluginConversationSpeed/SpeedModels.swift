import Foundation
import ProviderMessage

// MARK: - Message Speed Extension

extension Message {
    /// 用于速度计算的有效时长（毫秒）。
    ///
    /// `streamingDurationMs` 从第一个 token 开始计时。如果供应商缓冲了整个响应
    /// 再一次性发送，该值可能接近零。此时 `latencyMs`（完整请求延迟）更能反映
    /// 用户感知速度。
    var speedDurationMs: Double? {
        let streaming = streamingDurationMs
        let latency = latencyMs

        switch (streaming, latency) {
        case let (s?, l?) where s > 0 && l > 0:
            return max(s, l)
        case let (s?, _) where s > 0:
            return s
        case let (_, l?) where l > 0:
            return l
        default:
            return nil
        }
    }

    /// 输出速度（tokens/s）。
    var speedTokensPerSecond: Double? {
        guard let outputTokens = outputTokenCount,
              let durationMs = speedDurationMs,
              durationMs > 0 else {
            return nil
        }
        return Double(outputTokens) / (durationMs / 1000.0)
    }
}

// MARK: - Speed Sample

/// 一次带速度数据的消息样本。
struct SpeedSample: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let createdAt: Date
    let tokensPerSecond: Double
    let message: Message

    static func samples(from messages: [Message]) -> [SpeedSample] {
        messages
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { message -> (Date, Double, Message)? in
                guard let tps = message.speedTokensPerSecond else { return nil }
                return (message.createdAt, tps, message)
            }
            .enumerated()
            .map { offset, sample in
                SpeedSample(
                    id: sample.2.id,
                    index: offset,
                    createdAt: sample.0,
                    tokensPerSecond: sample.1,
                    message: sample.2
                )
            }
    }

    static func averageTokensPerSecond(from samples: [SpeedSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0) { $0 + $1.tokensPerSecond }
        return total / Double(samples.count)
    }
}

// MARK: - Speed Unavailability

/// 流式速度不可用时的原因分类。
enum SpeedUnavailability: String, Equatable {
    case noConversationSelected
    case waitingForResponse
    case missingOutputTokens
    case missingDuration
    case missingOutputTokensAndDuration

    static func reason(for message: Message?) -> SpeedUnavailability {
        guard let message else { return .waitingForResponse }

        let outputTokens = message.outputTokenCount
        let duration = message.speedDurationMs

        switch (outputTokens, duration) {
        case (nil, nil):
            return .missingOutputTokensAndDuration
        case (nil, _):
            return .missingOutputTokens
        case (_, nil):
            return .missingDuration
        case (.some(_), .some(_)):
            return .waitingForResponse
        }
    }

    var localizedExplanation: String {
        switch self {
        case .noConversationSelected:
            return "No conversation selected. Select a conversation to see streaming speed."
        case .waitingForResponse:
            return "Waiting for the first assistant response with speed data."
        case .missingOutputTokens:
            return "The provider did not report output token count."
        case .missingDuration:
            return "The provider did not report streaming duration."
        case .missingOutputTokensAndDuration:
            return "The provider did not report output tokens or streaming duration."
        }
    }
}
