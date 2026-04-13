import Foundation
import MagicKit
import SwiftData

/// 请求日志历史管理器（HTTP 视角）
actor RequestLogHistoryManager: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = false
    static let shared = RequestLogHistoryManager()

    private let container: ModelContainer
    private let retentionPeriod: TimeInterval = 7 * 24 * 60 * 60
    private let maxRecords = 10000

    private init() {
        let schema = Schema([RequestLogItem.self])
        let dbDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("RequestLogPlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("history.sqlite")

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

    func add(metadata: RequestMetadata) async {
        let context = ModelContext(container)
        let item = RequestLogItem(
            requestId: metadata.requestId,
            timestamp: metadata.sentAt,
            method: metadata.method,
            requestURL: metadata.url,
            requestHeadersJSON: toJSONString(metadata.requestHeaders),
            requestBodySize: metadata.requestBodySizeBytes,
            requestBodyPreview: metadata.requestBodyPreview,
            responseStatusCode: metadata.responseStatusCode,
            responseHeadersJSON: toJSONString(metadata.responseHeaders),
            isSuccess: metadata.isSuccess,
            errorMessage: metadata.error?.localizedDescription,
            duration: metadata.duration
        )
        context.insert(item)

        let descriptor = FetchDescriptor<RequestLogItem>()
        if let count = try? context.fetchCount(descriptor), count > maxRecords {
            await cleanupOldData(context: context)
        }
        try? context.save()
    }

    func query(from startTime: Date, to endTime: Date) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(from: startTime, to: endTime),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    func getLatest(limit: Int = 100) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RequestLogItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    func getStats() async -> RequestLogStats {
        let context = ModelContext(container)

        let total = (try? context.fetchCount(FetchDescriptor<RequestLogItem>())) ?? 0
        let success = (try? context.fetchCount(FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(isSuccess: true)
        ))) ?? 0
        let all = (try? context.fetch(FetchDescriptor<RequestLogItem>())) ?? []
        let durations = all.compactMap(\.duration)
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        return RequestLogStats(
            totalRequests: total,
            successCount: success,
            failedCount: max(total - success, 0),
            successRate: total > 0 ? Double(success) / Double(total) : 0,
            averageDuration: avgDuration
        )
    }

    func cleanup() async {
        let context = ModelContext(container)
        await cleanupOldData(context: context)
    }

    func clearAll() async {
        let context = ModelContext(container)
        let allItems = (try? context.fetch(FetchDescriptor<RequestLogItem>())) ?? []
        for item in allItems {
            context.delete(item)
        }
        try? context.save()
    }

    private func cleanupOldData(context: ModelContext) async {
        let cutoffTime = Date().addingTimeInterval(-retentionPeriod)
        let descriptor = FetchDescriptor<RequestLogItem>(
            predicate: #Predicate<RequestLogItem> { item in
                item.timestamp < cutoffTime
            }
        )
        let oldItems = (try? context.fetch(descriptor)) ?? []
        for item in oldItems {
            context.delete(item)
        }
        try? context.save()
    }

    private func toJSONString(_ dict: [String: String]?) -> String? {
        guard let dict else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct RequestLogStats: Sendable {
    var totalRequests: Int = 0
    var successCount: Int = 0
    var failedCount: Int = 0
    var successRate: Double = 0
    var averageDuration: Double = 0
}
