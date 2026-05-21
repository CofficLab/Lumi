import Foundation
import MagicKit
import HttpKit
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

    func add(metadata: HTTPRequestMetadata) async {
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

    nonisolated func getContext() -> ModelContext {
        ModelContext(container)
    }

    func getLatest(limit: Int = 100, offset: Int = 0) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RequestLogItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    func query(isSuccess: Bool, limit: Int, offset: Int = 0) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(isSuccess: isSuccess),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    func getStats() async -> RequestLogStats {
        let context = ModelContext(container)

        let total = (try? context.fetchCount(FetchDescriptor<RequestLogItem>())) ?? 0
        let success = (try? context.fetchCount(FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(isSuccess: true)
        ))) ?? 0
        let durationSummary = fetchDurationSummary(context: context)
        let avgDuration = durationSummary.count == 0 ? 0 : durationSummary.sum / Double(durationSummary.count)

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

    private func fetchDurationSummary(context: ModelContext) -> (sum: Double, count: Int) {
        let batchSize = 250
        var offset = 0
        var sum: Double = 0
        var count = 0

        while true {
            var descriptor = FetchDescriptor<RequestLogItem>(
                predicate: #Predicate<RequestLogItem> { item in
                    item.duration != nil
                }
            )
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset

            let items = (try? context.fetch(descriptor)) ?? []
            guard !items.isEmpty else { break }

            for item in items {
                if let duration = item.duration {
                    sum += duration
                    count += 1
                }
            }

            guard items.count == batchSize else { break }
            offset += batchSize
        }

        return (sum, count)
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
