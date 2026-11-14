import Foundation
import LumiLocalizationKit
import ProviderMessage

// MARK: - Message Speed Extension

extension Message {
    /// 用于速度计算的有效时长（毫秒）。
    ///
    /// 优先用 `streamingDurationMs`（从第一个 token 到结束的生成时长）作为分母，
    /// TPS 只衡量生成速度，不含排队/预填充（TTFT）。仅当 streaming 缺失或为零
    /// （供应商缓冲整个响应再一次性发送）时，才回退到 `latencyMs`（完整请求延迟）。
    var speedDurationMs: Double? {
        // 旧版把计时写进 metadata，没有强类型列。强类型优先、metadata 兜底，
        // 否则升级后历史响应的样本会被整体丢弃（#1029）。
        let streaming = streamingDurationMs ?? legacyTimingMs("streamingDurationMs")
        let latency = latencyMs ?? legacyTimingMs("latencyMs")

        // latency = TTFT + streaming，取 max 会让完整延迟恒胜，把预填充时间
        // 算进生成时长，系统性低估 TPS（#237）。streaming 有效时直接用它。
        switch (streaming, latency) {
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

    /// 首 token 延迟（毫秒）；强类型字段缺失时回退到旧版 metadata。
    var speedTimeToFirstTokenMs: Double? {
        timeToFirstTokenMs ?? legacyTimingMs("timeToFirstTokenMs")
    }

    private func legacyTimingMs(_ key: String) -> Double? {
        metadata[key].flatMap(Double.init)
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
            .filter { $0.role == .assistant }
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
            return pluginLocalization.string("No conversation selected. Select a conversation to see streaming speed.")
        case .waitingForResponse:
            return pluginLocalization.string("Waiting for the first assistant response with speed data.")
        case .missingOutputTokens:
            return pluginLocalization.string("The provider did not report output token count.")
        case .missingDuration:
            return pluginLocalization.string("The provider did not report streaming duration.")
        case .missingOutputTokensAndDuration:
            return pluginLocalization.string("The provider did not report output tokens or streaming duration.")
        }
    }
}
