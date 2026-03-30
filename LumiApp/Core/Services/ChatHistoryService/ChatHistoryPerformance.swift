import Foundation
import SwiftData

// MARK: - 性能统计扩展

extension ChatHistoryService {

    /// 获取每个供应商和模型的平均耗时
    /// - Returns: 字典，键为 (providerId, modelName)，值为平均耗时（毫秒）
    func getModelLatencyStats() -> [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] {
        let context = getContext()

        // 获取所有有 latency 数据的消息
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.latency != nil && $0.providerId != nil && $0.modelName != nil }
        )

        guard let messageEntities = try? context.fetch(descriptor) else {
            AppLogger.core.error("\(Self.t)❌ 获取消息失败")
            return []
        }

        // 按 providerId 和 modelName 分组统计
        var statsDict: [String: [String: (total: Double, count: Int)]] = [:]

        for entity in messageEntities {
            guard let providerId = entity.providerId,
                  let modelName = entity.modelName,
                  let latency = entity.latency else {
                continue
            }

            if statsDict[providerId] == nil {
                statsDict[providerId] = [:]
            }

            var existing = statsDict[providerId]?[modelName] ?? (total: 0, count: 0)
            existing.total += latency
            existing.count += 1
            statsDict[providerId]?[modelName] = existing
        }

        // 转换为数组并计算平均值
        var result: [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] = []

        for (providerId, models) in statsDict {
            for (modelName, stats) in models {
                let avgLatency = stats.count > 0 ? stats.total / Double(stats.count) : 0
                result.append((providerId: providerId, modelName: modelName, avgLatency: avgLatency, sampleCount: stats.count))
            }
        }

        // 按 providerId 和 modelName 排序
        result.sort {
            if $0.providerId != $1.providerId {
                return $0.providerId < $1.providerId
            }
            return $0.modelName < $1.modelName
        }

        return result
    }

    /// 获取每个供应商和模型的详细性能统计
    /// - Returns: 字典，键为 (providerId, modelName)，值为详细统计数据
    func getModelDetailedStats() -> [String: ModelPerformanceStats] {
        let context = getContext()

        // 获取所有有性能数据的消息
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.latency != nil && $0.providerId != nil && $0.modelName != nil }
        )

        guard let messageEntities = try? context.fetch(descriptor) else {
            AppLogger.core.error("\(Self.t)❌ 获取消息失败")
            return [:]
        }

        // 按 providerId 和 modelName 分组统计
        var statsDict: [String: ModelPerformanceStats] = [:]

        for entity in messageEntities {
            guard let providerId = entity.providerId,
                  let modelName = entity.modelName,
                  let latency = entity.latency else {
                continue
            }

            let key = "\(providerId)|\(modelName)"
            var stats = statsDict[key] ?? ModelPerformanceStats(
                providerId: providerId,
                modelName: modelName,
                sampleCount: 0,
                totalLatency: 0,
                totalTTFT: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0
            )

            stats.sampleCount += 1
            stats.totalLatency += latency

            if let ttft = entity.timeToFirstToken {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }

            if let inputTokens = entity.inputTokens {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }

            // 只统计同时有 outputTokens 和 streamingDuration 的消息
            if let outputTokens = entity.outputTokens,
               let streamingDuration = entity.streamingDuration {
                stats.totalOutputTokens += outputTokens
                stats.outputTokenCount += 1
                stats.totalStreamingDuration += streamingDuration
                stats.streamingDurationCount += 1
            }

            statsDict[key] = stats
        }

        return statsDict
    }
}
