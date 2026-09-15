import Foundation
import ProviderLLMContext
import ProviderMessage

// MARK: - Sample

/// 一次请求的上下文使用采样点。
///
/// 采样来自 assistant 消息：
/// - `tokens` 优先取服务端上报的 `inputTokenCount`（那一轮真实的 prompt 大小），
///   此时 `isEstimated == false`；
/// - 供应商未上报 usage 时，用 `LLMContextTokenEstimator` 估算该消息之前的累计历史，
///   此时 `isEstimated == true`，UI 需要标注口径。
struct ContextUsageSample: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let date: Date
    let tokens: Int
    let isEstimated: Bool
}

// MARK: - Compaction Marker

/// 曲线上的压缩标记。
struct ContextUsageCompactionMarker: Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// 标记落在第几个采样点之后；`-1` 表示早于首个采样点。
    let afterSampleIndex: Int
    let reason: MessageTimelineEvent.ContextCompactionReason
}

// MARK: - History

/// 上下文使用历史。
///
/// 与速度插件相同，历史不单独持久化，而是每次从会话消息现算：
/// 采样点即每条上报了 usage 的 assistant 消息，因此曲线能直接反映
/// 上下文增长以及压缩后的回落。
struct ContextUsageHistory: Equatable {
    let samples: [ContextUsageSample]
    let compactionMarkers: [ContextUsageCompactionMarker]

    static let empty = ContextUsageHistory(samples: [], compactionMarkers: [])

    var latestTokens: Int? { samples.last?.tokens }

    var peakTokens: Int? { samples.map(\.tokens).max() }

    var minimumTokens: Int? { samples.map(\.tokens).min() }

    var averageTokens: Int? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0) { $0 + $1.tokens } / samples.count
    }

    var hasEstimatedSamples: Bool { samples.contains { $0.isEstimated } }

    /// 从会话消息构建历史曲线。
    ///
    /// 压缩事件本身是时间线事件消息（不是真实请求），因此不计入采样，
    /// 只作为曲线上的标记。
    static func build(from messages: [Message]) -> ContextUsageHistory {
        let ordered = messages.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.createdAt < rhs.createdAt
        }

        var cumulativeTokens = 0
        var samples: [ContextUsageSample] = []
        var markers: [ContextUsageCompactionMarker] = []

        for message in ordered {
            if MessageTimelineEvent.isContextCompaction(message) {
                guard MessageTimelineEvent.isActualContextCompaction(message) else { continue }
                markers.append(
                    ContextUsageCompactionMarker(
                        id: message.id,
                        date: message.createdAt,
                        afterSampleIndex: samples.count - 1,
                        reason: MessageTimelineEvent.compactionReason(for: message)
                    )
                )
                continue
            }

            if message.role == .assistant {
                // 该轮输入 = 处理本条之前已累积的历史；assistant 自身的输出不属于输入。
                if let actual = message.inputTokenCount, actual > 0 {
                    samples.append(
                        ContextUsageSample(
                            id: message.id,
                            index: samples.count,
                            date: message.createdAt,
                            tokens: actual,
                            isEstimated: false
                        )
                    )
                } else if cumulativeTokens > 0 {
                    samples.append(
                        ContextUsageSample(
                            id: message.id,
                            index: samples.count,
                            date: message.createdAt,
                            tokens: cumulativeTokens,
                            isEstimated: true
                        )
                    )
                }
            }

            if isLLMRelevant(message.role) {
                cumulativeTokens += LLMContextTokenEstimator.estimate(message: message)
            }
        }

        return ContextUsageHistory(samples: samples, compactionMarkers: markers)
    }

    private static func isLLMRelevant(_ role: MessageRole) -> Bool {
        switch role {
        case .system, .user, .assistant, .tool: return true
        case .error, .status: return false
        }
    }
}

#if DEBUG
extension ContextUsageHistory {
    /// 预览用样例：上下文逐步增长后因压缩回落。
    static var preview: ContextUsageHistory {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let values: [Int] = [12_000, 18_500, 26_000, 34_000, 41_500, 15_000, 22_000, 29_500]
        let samples = values.enumerated().map { offset, tokens in
            ContextUsageSample(
                id: UUID(),
                index: offset,
                date: base.addingTimeInterval(Double(offset) * 600),
                tokens: tokens,
                isEstimated: false
            )
        }
        let markers = [
            ContextUsageCompactionMarker(
                id: UUID(),
                date: base.addingTimeInterval(3_000),
                afterSampleIndex: 4,
                reason: .hardThreshold
            ),
        ]
        return ContextUsageHistory(samples: samples, compactionMarkers: markers)
    }
}

extension Message {
    /// 预览用的压缩时间线事件。
    static func previewContextCompaction(
        reason: MessageTimelineEvent.ContextCompactionReason = .hardThreshold,
        createdAt: Date = Date()
    ) -> Message {
        Message(
            conversationID: UUID(),
            role: .status,
            content: String(localized: "Conversation compacted", defaultValue: "会话已压缩", bundle: .module),
            createdAt: createdAt,
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.contextCompaction,
                MessageTimelineEvent.actualContextCompactionKey: MessageTimelineEvent.actualContextCompactionValue,
                MessageTimelineEvent.contextCompactionReasonKey: reason.rawValue,
                MessageTimelineEvent.contextCompactionContextWindowTokensKey: "128000",
                MessageTimelineEvent.contextCompactionInputTokenLimitKey: "112000",
                MessageTimelineEvent.contextCompactionOriginalEstimateKey: "104000",
                MessageTimelineEvent.contextCompactionCompactedEstimateKey: "21000",
            ],
            providerID: "openai",
            modelName: "gpt-4o",
            renderKind: MessageTimelineEvent.contextCompactionRenderKind
        )
    }
}
#endif
