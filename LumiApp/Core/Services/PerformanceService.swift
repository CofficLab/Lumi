import Foundation
import SwiftData

/// 性能统计服务
///
/// 从消息实体的 metrics 关系中聚合 LLM 调用性能数据，
/// 按供应商/模型分组提供延迟、TTFT、Token 吞吐等统计指标。
///
/// ## 设计原则
///
/// - **只读查询**：不写入任何数据，仅聚合统计
/// - **线程安全**：标记为 `@MainActor`，所有查询在主线程执行
@MainActor
final class PerformanceService: SuperLog, Sendable {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose: Bool = false

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init(modelContainer: ModelContainer, reason: String) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 性能统计服务已初始化")
        }
    }

    private func getContext() -> ModelContext {
        return modelContext
    }
}

// MARK: - 延迟统计

extension PerformanceService {

    /// 获取每个供应商和模型的平均耗时
    ///
    /// - Returns: 数组，每项包含供应商 ID、模型名称、平均延迟和样本数
    func getModelLatencyStats() -> [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] {
        let context = getContext()

        // SwiftData predicate 不稳定支持 optional relationship 判空；metrics 在循环中继续过滤。
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { msg in
                msg.providerId != nil && msg.modelName != nil
            }
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
                  let metrics = entity.metrics,
                  let latency = metrics.latency else {
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
}

// MARK: - 详细统计

extension PerformanceService {

    /// 获取每个供应商和模型的详细性能统计
    ///
    /// - Returns: 字典，键为 "providerId|modelName"，值为详细统计数据
    func getModelDetailedStats() -> [String: ModelPerformanceStats] {
        let context = getContext()

        // SwiftData predicate 不稳定支持 optional relationship 判空；metrics 在循环中继续过滤。
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { msg in
                msg.providerId != nil && msg.modelName != nil
            }
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
                  let metrics = entity.metrics,
                  let latency = metrics.latency else {
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

            if let ttft = metrics.timeToFirstToken {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }

            if let inputTokens = metrics.inputTokens {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }

            // 只统计同时有 outputTokens 和 streamingDuration 的消息
            if let outputTokens = metrics.outputTokens,
               let streamingDuration = metrics.streamingDuration {
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
