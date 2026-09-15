import Foundation
import ProviderMessage

// MARK: - Request Metrics

/// 单次请求的缓存用量（已解析并归一化）。
///
/// 解析规则与聚合统计共用，避免「当前值」和「历史曲线」两处口径漂移。
struct CacheHitRateRequestMetrics: Equatable {
    /// 缓存读取 tokens，已 clamp 到不超过总输入 tokens。
    let cachedTokens: Int
    /// 该次请求的总输入 tokens。
    let totalTokens: Int

    /// 单次请求命中率（0...1）。
    var hitRate: Double {
        Double(cachedTokens) / Double(totalTokens)
    }

    /// 从 assistant 消息解析缓存用量；供应商未上报有效数据时返回 `nil`。
    ///
    /// 新消息使用 ProviderMessage 的强类型 token 字段；旧消息仍可从
    /// metadata 读取，避免迁移前已保存的消息完全丢失统计。
    static func parse(_ message: Message) -> CacheHitRateRequestMetrics? {
        guard message.role == .assistant else { return nil }
        guard let cached = metricValue(
            message.cachedInputTokenCount,
            metadata: message.metadata,
            key: "cachedInputTokens"
        ),
        let total = metricValue(
            message.cacheTotalInputTokenCount ?? message.inputTokenCount,
            metadata: message.metadata,
            key: "cacheTotalInputTokens"
        ),
        cached >= 0,
        total > 0 else {
            return nil
        }

        return CacheHitRateRequestMetrics(
            cachedTokens: min(cached, total),
            totalTokens: total
        )
    }

    private static func metricValue(
        _ value: Int?,
        metadata: [String: String],
        key: String
    ) -> Int? {
        value ?? metadata[key].flatMap(Int.init)
    }
}

// MARK: - Sample

/// 一次请求的缓存命中率采样点。
///
/// 同时携带单次命中率与累计命中率：
/// - `hitRate` 反映该次请求的即时表现，会话首条必然偏低，波动较大；
/// - `cumulativeHitRate` 是截至该次请求的 token 加权累计值，单调平滑，
///   更能反映缓存是否真正生效。
struct CacheHitRateSample: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let date: Date
    /// 单次请求命中率（0...1）。
    let hitRate: Double
    /// 截至该次请求的累计命中率（0...1），按 token 加权。
    let cumulativeHitRate: Double
    let cachedTokens: Int
    let totalTokens: Int
}

// MARK: - History

/// 缓存命中率历史。
///
/// 与速度 / 上下文插件一致，历史不单独持久化，而是每次从会话消息现算：
/// 采样点即每条上报了缓存用量的 assistant 消息。
struct CacheHitRateHistory: Equatable {
    let samples: [CacheHitRateSample]

    static let empty = CacheHitRateHistory(samples: [])

    var isEmpty: Bool { samples.isEmpty }

    var minimumHitRate: Double? { samples.map(\.hitRate).min() }

    var averageHitRate: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0) { $0 + $1.hitRate } / Double(samples.count)
    }

    var maximumHitRate: Double? { samples.map(\.hitRate).max() }

    /// 最新一条的累计命中率。
    var latestCumulativeHitRate: Double? { samples.last?.cumulativeHitRate }

    /// 从会话消息构建历史曲线。
    static func build(from messages: [Message]) -> CacheHitRateHistory {
        let ordered = messages.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.createdAt < rhs.createdAt
        }

        var samples: [CacheHitRateSample] = []
        var totalCachedTokens = 0
        var totalInputTokens = 0

        for message in ordered {
            guard let metrics = CacheHitRateRequestMetrics.parse(message) else { continue }

            totalCachedTokens += metrics.cachedTokens
            totalInputTokens += metrics.totalTokens

            samples.append(
                CacheHitRateSample(
                    id: message.id,
                    index: samples.count,
                    date: message.createdAt,
                    hitRate: metrics.hitRate,
                    cumulativeHitRate: Double(totalCachedTokens) / Double(totalInputTokens),
                    cachedTokens: metrics.cachedTokens,
                    totalTokens: metrics.totalTokens
                )
            )
        }

        return CacheHitRateHistory(samples: samples)
    }
}

// MARK: - Preview

#if DEBUG
extension CacheHitRateHistory {
    /// 预览用样例消息：首条未命中，随后逐步爬升并出现一次回落后再恢复。
    static var previewMessages: [Message] {
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let pairs: [(cached: Int, total: Int)] = [
            (0, 8_000),
            (5_200, 11_000),
            (9_400, 15_500),
            (13_000, 19_000),
            (2_100, 22_000),
            (14_800, 26_500),
            (19_500, 31_000),
            (24_600, 35_500),
        ]

        return pairs.enumerated().map { offset, pair in
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "sample \(offset)",
                createdAt: base.addingTimeInterval(Double(offset) * 600),
                cachedInputTokenCount: pair.cached,
                cacheTotalInputTokenCount: pair.total
            )
        }
    }

    /// 预览用样例历史。
    static var preview: CacheHitRateHistory {
        .build(from: previewMessages)
    }
}
#endif
