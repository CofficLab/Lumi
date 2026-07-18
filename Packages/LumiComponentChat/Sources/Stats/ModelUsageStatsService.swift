import Foundation
import LumiComponentMessage
import LLMKit

/// 一条「快速模型」记录, 用于快速模型榜。
public struct ModelFastModelEntry: Sendable, Equatable {
    public let provider: LumiLLMProviderInfo
    public let model: String
    public let avgTPS: Double
    public let sampleCount: Int

    public init(provider: LumiLLMProviderInfo, model: String, avgTPS: Double, sampleCount: Int) {
        self.provider = provider
        self.model = model
        self.avgTPS = avgTPS
        self.sampleCount = sampleCount
    }
}

/// 由消息流聚合出的用量/性能快照, 供模型卡片等处展示。
public struct ModelUsageStatsSnapshot: Sendable {
    public let detailedStats: [String: ModelPerformanceStats]
    public let fastModels: [ModelFastModelEntry]
    /// key: "providerID|modelName" → 最近一段窗口期内每天的 token 用量序列。
    public let dailyUsage: [String: ModelDailyTokenSeries]

    public init(
        detailedStats: [String: ModelPerformanceStats],
        fastModels: [ModelFastModelEntry],
        dailyUsage: [String: ModelDailyTokenSeries]
    ) {
        self.detailedStats = detailedStats
        self.fastModels = fastModels
        self.dailyUsage = dailyUsage
    }
}

/// 从聊天消息聚合模型用量与性能统计。纯函数, 无 UI 依赖, 可直接单测。
public enum ModelUsageStatsService {
    /// 每日用量默认展示窗口(天)。集中在此处, 便于将来做成 7/14/30 切换。
    public static let defaultDailyUsageWindowDays = 14

    /// 从一批消息构建统计快照。
    ///
    /// - 仅统计 assistant 消息的 `latencyMs`/`tokensPerSecond`/token 元数据。
    /// - `dailyUsage` 按天分桶并连续补零。
    public static func buildSnapshot(
        messages: [LumiChatMessage],
        providers: [LumiLLMProviderInfo],
        dailyUsageWindowDays: Int = defaultDailyUsageWindowDays,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> ModelUsageStatsSnapshot {
        var detailedStats: [String: ModelPerformanceStats] = [:]

        for message in messages where message.role == .assistant {
            guard let providerID = message.providerID,
                  let modelName = message.modelName,
                  let latencyMs = message.latencyMs else {
                continue
            }

            let key = "\(providerID)|\(modelName)"
            var stats = detailedStats[key] ?? ModelPerformanceStats(
                providerID: providerID,
                modelName: modelName
            )

            stats.sampleCount += 1
            stats.totalLatency += latencyMs

            if let ttft = message.timeToFirstTokenMs {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }

            if let inputTokens = message.inputTokenCount {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }

            if let outputTokens = message.outputTokenCount,
               let streamingDurationMs = message.streamingDurationMs {
                stats.totalOutputTokens += outputTokens
                stats.outputTokenCount += 1
                stats.totalStreamingDuration += streamingDurationMs
                stats.streamingDurationCount += 1
            }

            detailedStats[key] = stats
        }

        let providerMap = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        let fastModels = detailedStats.values
            .filter { $0.avgTPS > 0 && $0.sampleCount > 0 }
            .compactMap { stat -> ModelFastModelEntry? in
                guard let provider = providerMap[stat.providerID],
                      provider.availableModels.contains(stat.modelName) else {
                    return nil
                }
                return ModelFastModelEntry(
                    provider: provider,
                    model: stat.modelName,
                    avgTPS: stat.avgTPS,
                    sampleCount: stat.sampleCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.avgTPS == rhs.avgTPS {
                    return lhs.sampleCount > rhs.sampleCount
                }
                return lhs.avgTPS > rhs.avgTPS
            }

        return ModelUsageStatsSnapshot(
            detailedStats: detailedStats,
            fastModels: Array(fastModels.prefix(10)),
            dailyUsage: buildDailyUsage(
                messages: messages,
                windowDays: dailyUsageWindowDays,
                calendar: calendar,
                now: now
            )
        )
    }

    /// 从消息构建每个 (provider, model) 的按天 token 序列。纯函数, 无 UI 依赖。
    ///
    /// - 仅统计 assistant 消息; 每条贡献的 token 为 `(inputTokenCount ?? 0) + (outputTokenCount ?? 0)`。
    /// - 落在 `[startDay, today]` 区间内的消息才计入; 早于窗口的消息忽略。
    /// - 返回的序列保证连续补零(无数据的天为零桶), 便于柱状图渲染。
    static func buildDailyUsage(
        messages: [LumiChatMessage],
        windowDays: Int,
        calendar: Calendar,
        now: Date
    ) -> [String: ModelDailyTokenSeries] {
        guard windowDays > 0 else { return [:] }
        let today = calendar.startOfDay(for: now)
        guard let startDay = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) else {
            return [:]
        }

        // 预生成窗口内连续的每一天(含今天), 从最早到今天。
        let windowDays: [Date] = (0..<windowDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startDay)
        }
        let windowRange = windowDays.first!...windowDays.last!

        // 按天聚合每个 (provider|model) 的 token 用量。
        var daily: [String: [Date: (input: Int, output: Int)]] = [:]
        for message in messages where message.role == .assistant {
            guard let providerID = message.providerID,
                  let modelName = message.modelName else {
                continue
            }
            let day = calendar.startOfDay(for: message.createdAt)
            guard windowRange.contains(day) else { continue }

            let key = "\(providerID)|\(modelName)"
            let input = message.inputTokenCount ?? 0
            let output = message.outputTokenCount ?? 0
            let existing = daily[key]?[day] ?? (0, 0)
            daily[key, default: [:]][day] = (existing.input + input, existing.output + output)
        }

        // 为每个 (provider|model) 组装连续序列; 仅保留有实际用量的,
        // 避免给卡片渲染出空的图表(无 token 元数据的历史消息会贡献 0)。
        var series: [String: ModelDailyTokenSeries] = [:]
        for (key, dayMap) in daily {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let buckets = windowDays.map { day in
                let usage = dayMap[day] ?? (0, 0)
                return ModelDailyTokenBucket(
                    day: day,
                    inputTokens: usage.input,
                    outputTokens: usage.output
                )
            }
            let value = ModelDailyTokenSeries(
                providerID: parts[0],
                modelName: parts[1],
                buckets: buckets
            )
            guard value.hasData else { continue }
            series[key] = value
        }
        return series
    }
}
