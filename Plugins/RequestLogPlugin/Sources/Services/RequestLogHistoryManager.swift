import Foundation
import SuperLogKit
import HttpKit
import LumiKernel
import SwiftData
import os

/// 请求日志历史管理器（HTTP 视角）
public actor RequestLogHistoryManager: SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = true
    static let maxPageLimit = 1000
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "request-log.history")
    public static let shared = RequestLogHistoryManager()

    private let container: ModelContainer
    private let retentionPeriod: TimeInterval = 7 * 24 * 60 * 60
    private let maxRecords = 10000

    private init() {
        self.container = Self.makeInMemoryContainer(schema: Schema([RequestLogItem.self]))
    }

    init(databaseRootURL: URL) {
        self.container = Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) -> ModelContainer {
        let schema = Schema([RequestLogItem.self])
        let dbDir = databaseRootURL.appendingPathComponent("RequestLogPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("history.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)创建请求日志数据库目录失败：\(error.localizedDescription)")
            }
        }

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)打开请求日志数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)重建请求日志数据库失败，使用临时内存存储：\(error.localizedDescription)")
            }
            return makeInMemoryContainer(schema: schema)
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            preconditionFailure("Could not create in-memory RequestLog ModelContainer: \(error)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal")
        ]

        for url in storeURLs where fileManager.fileExists(atPath: url.path) {
            quarantineFile(at: url)
        }
    }

    private static func quarantineFileIfItBlocksDirectory(at url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        quarantineFile(at: url)
    }

    private static func quarantineFile(at url: URL) {
        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)隔离请求日志数据库文件失败：\(error.localizedDescription)")
            }
        }
    }

    @discardableResult
    public func add(metadata: HTTPRequestMetadata) async -> Bool {
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
            responseBodySize: metadata.responseBodySizeBytes,
            responseBodyPreview: metadata.responseBodyPreview,
            isSuccess: metadata.isSuccess,
            errorMessage: metadata.error?.localizedDescription,
            duration: metadata.duration
        )
        context.insert(item)

        let descriptor = FetchDescriptor<RequestLogItem>()
        if let count = try? context.fetchCount(descriptor), count > maxRecords {
            await cleanupOldData(context: context)
        }
        return save(context, operation: "保存请求日志")
    }

    public func query(from startTime: Date, to endTime: Date) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(from: startTime, to: endTime),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    public func getLatest(limit: Int = 100, offset: Int = 0) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        let pagination = Self.normalizedPagination(limit: limit, offset: offset)
        var descriptor = FetchDescriptor<RequestLogItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = pagination.limit
        descriptor.fetchOffset = pagination.offset
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    public func query(isSuccess: Bool, limit: Int, offset: Int = 0) async -> [RequestLogItemDTO] {
        let context = ModelContext(container)
        let pagination = Self.normalizedPagination(limit: limit, offset: offset)
        var descriptor = FetchDescriptor<RequestLogItem>(
            predicate: RequestLogItem.predicate(isSuccess: isSuccess),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = pagination.limit
        descriptor.fetchOffset = pagination.offset
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map { RequestLogItemDTO(from: $0) }
    }

    public func getStats() async -> RequestLogStats {
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

    public func cleanup() async {
        let context = ModelContext(container)
        await cleanupOldData(context: context)
    }

    @discardableResult
    public func clearAll() async -> Bool {
        let context = ModelContext(container)
        let allItems = (try? context.fetch(FetchDescriptor<RequestLogItem>())) ?? []
        for item in allItems {
            context.delete(item)
        }
        return save(context, operation: "清空请求日志")
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
        _ = save(context, operation: "清理过期请求日志")
    }

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)\(operation)失败：\(error.localizedDescription)")
            }
            return false
        }
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

    static func normalizedPagination(limit: Int, offset: Int) -> (limit: Int, offset: Int) {
        (
            limit: min(max(limit, 1), maxPageLimit),
            offset: max(offset, 0)
        )
    }
}
