import Foundation
import MagicKit
import SwiftData

/// 请求日志历史管理器
///
/// 负责请求日志数据的增删改查和数据清理。
/// 使用 SwiftData 持久化存储。
actor RequestLogHistoryManager: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false
    
    // MARK: - Singleton
    
    static let shared = RequestLogHistoryManager()
    
    // MARK: - Properties
    
    private let container: ModelContainer
    
    /// 数据保留期限（秒）- 默认保留 7 天
    private let retentionPeriod: TimeInterval = 7 * 24 * 60 * 60
    
    /// 最大记录数 - 默认 10000 条
    private let maxRecords = 10000
    
    // MARK: - Initialization
    
    private init() {
        // 定义 Schema
        let schema = Schema([RequestLogItem.self])
        
        // 数据库路径
        let dbDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("RequestLogPlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("history.sqlite")
        
        // 配置 ModelContainer
        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create RequestLog ModelContainer: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// 添加请求日志
    ///
    /// - Parameter metadata: 请求元数据
    /// - Parameter response: 响应消息
    func add(metadata: RequestMetadata, response: ChatMessage?) async {
        let context = ModelContext(container)
        
        // 从 metadata 提取会话 ID
        let conversationId = metadata.messages?.first?.conversationId ?? UUID()
        
        // 构建消息摘要
        let messagesSummary = buildMessagesSummary(from: metadata.messages)
        
        // 构建工具名称列表
        let toolNames = metadata.tools?.map(\.name).joined(separator: ", ")
        
        // 构建临时提示词摘要
        let transientPromptsSummary = metadata.transientPrompts?.joined(separator: "\n---\n")
        
        // 构建响应内容预览
        let responsePreview = response?.content.prefix(500).replacingOccurrences(of: "\n", with: " ")
        
        // 构建工具调用名称列表
        let toolCallNames = response?.toolCalls?.map(\.name).joined(separator: ", ")
        
        // 创建日志项
        let item = RequestLogItem(
            conversationId: conversationId,
            timestamp: metadata.timestamp,
            requestURL: metadata.url,
            requestBodySize: metadata.bodySizeBytes,
            providerId: metadata.config?.providerId,
            modelName: metadata.config?.model,
            temperature: metadata.config?.temperature,
            maxTokens: metadata.config?.maxTokens,
            messageCount: metadata.messages?.count ?? 0,
            messagesSummary: messagesSummary,
            toolCount: metadata.tools?.count ?? 0,
            toolNames: toolNames,
            transientPromptCount: metadata.transientPrompts?.count ?? 0,
            transientPromptsSummary: transientPromptsSummary,
            isSuccess: metadata.error == nil && response != nil,
            errorMessage: metadata.error?.localizedDescription,
            responseContentPreview: responsePreview,
            hasToolCalls: response?.hasToolCalls ?? false,
            toolCallNames: toolCallNames,
            latency: response?.latency,
            inputTokens: response?.inputTokens,
            outputTokens: response?.outputTokens,
            totalTokens: response?.totalTokens,
            finishReason: response?.finishReason,
            duration: metadata.duration
        )
        
        context.insert(item)
        
        // 定期清理过期数据
        let descriptor = FetchDescriptor<RequestLogItem>()
        if let count = try? context.fetchCount(descriptor), count > maxRecords {
            await cleanupOldData(context: context)
        }
        
        try? context.save()
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)已记录请求日志：\(item.id)")
        }
    }
    
    /// 查询指定时间范围内的日志
    func query(from startTime: Date, to endTime: Date) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(from: startTime, to: endTime),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        descriptor.fetchLimit = 1000
        
        do {
            let items = try context.fetch(descriptor)
            return items.map { RequestLogItemDTO(from: $0) }
        } catch {
            AppLogger.core.error("\(Self.t)查询失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 按会话 ID 查询日志
    func query(conversationId: UUID) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(conversationId: conversationId),
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        descriptor.fetchLimit = 100
        
        do {
            let items = try context.fetch(descriptor)
            return items.map { RequestLogItemDTO(from: $0) }
        } catch {
            return []
        }
    }
    
    /// 获取最新 N 条日志
    func getLatest(limit: Int = 100) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        
        var descriptor = FetchDescriptor<RequestLogItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            let items = try context.fetch(descriptor)
            return items.map { RequestLogItemDTO(from: $0) }
        } catch {
            return []
        }
    }
    
    /// 获取统计信息
    func getStats() async -> RequestLogStats {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<RequestLogItem>()
        
        guard let totalCount = try? context.fetchCount(descriptor) else {
            return RequestLogStats()
        }
        
        // 获取成功率
        let successDescriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(isSuccess: true)
        )
        let successCount = (try? context.fetchCount(successDescriptor)) ?? 0
        
        // 获取平均耗时
        let allItems = (try? context.fetch(FetchDescriptor<RequestLogItem>())) ?? []
        let durations = allItems.compactMap { $0.duration }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        
        // 获取总 Token 数
        let totalInputTokens = allItems.compactMap { $0.inputTokens }.reduce(0, +)
        let totalOutputTokens = allItems.compactMap { $0.outputTokens }.reduce(0, +)
        
        return RequestLogStats(
            totalRequests: totalCount,
            successCount: successCount,
            failedCount: totalCount - successCount,
            successRate: totalCount > 0 ? Double(successCount) / Double(totalCount) : 0,
            averageDuration: avgDuration,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens
        )
    }
    
    /// 清理过期数据
    func cleanup() async {
        let context = ModelContext(container)
        await cleanupOldData(context: context)
    }
    
    /// 清空所有日志
    func clearAll() async {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<RequestLogItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }
        
        for item in allItems {
            context.delete(item)
        }
        
        try? context.save()
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)已清空所有日志")
        }
    }
    
    // MARK: - Private Helpers
    
    /// 构建消息摘要
    private func buildMessagesSummary(from messages: [ChatMessage]?) -> String? {
        guard let messages = messages, !messages.isEmpty else { return nil }
        
        let summary = messages.enumerated().map { (index, message) in
            let role = message.role.rawValue
            let content = String(message.content.prefix(100)).replacingOccurrences(of: "\n", with: " ")
            let tools = message.toolCalls?.map(\.name).joined(separator: ", ") ?? ""
            return "[\(index)] \(role): \(content)\(tools.isEmpty ? "" : " [\(tools)]")"
        }.joined(separator: "\n")
        
        return summary
    }
    
    /// 清理过期数据
    private func cleanupOldData(context: ModelContext) async {
        let cutoffTime = Date().addingTimeInterval(-retentionPeriod)
        
        let descriptor = FetchDescriptor<RequestLogItem>(
            predicate: #Predicate<RequestLogItem> { item in
                item.timestamp < cutoffTime
            }
        )
        
        guard let oldItems = try? context.fetch(descriptor) else { return }
        
        for item in oldItems {
            context.delete(item)
        }
        
        try? context.save()
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)清理了 \(oldItems.count) 条过期记录")
        }
    }
}

// MARK: - 统计信息

/// 请求日志统计信息
struct RequestLogStats: Sendable {
    var totalRequests: Int = 0
    var successCount: Int = 0
    var failedCount: Int = 0
    var successRate: Double = 0
    var averageDuration: Double = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
}