import Foundation
import SwiftData
import LumiKernel
import SuperLogKit
import os

/// 工具调用记录的纯数据副本,用于在 SwiftUI 视图中展示,
/// 与 SwiftData actor 隔离,避免跨 actor 传递 managed 对象。
struct ToolCallRecordDTO: Identifiable, Sendable {
    let id: String
    let toolName: String
    let toolDisplayName: String
    let turnID: UUID?
    let conversationID: String
    let createdAt: Date
    let startedAt: Date
    let completedAt: Date?
    let duration: Double?
    let argumentsJSON: String
    let resultContent: String
    let resultIsError: Bool
    let riskLevel: String
    let turnControl: String?

    init(from model: ToolCallRecordModel) {
        self.id = model.id
        self.toolName = model.toolName
        self.toolDisplayName = model.toolDisplayName
        self.turnID = model.turnID.flatMap(UUID.init(uuidString:))
        self.conversationID = model.conversationID
        self.createdAt = model.createdAt
        self.startedAt = model.startedAt
        self.completedAt = model.completedAt
        self.duration = model.duration
        self.argumentsJSON = model.argumentsJSON
        self.resultContent = model.resultContent
        self.resultIsError = model.resultIsError
        self.riskLevel = model.riskLevel
        self.turnControl = model.turnControl
    }
}

/// 使用 SwiftData 持久化「工具调用」记录的后台存储服务。
///
/// 存储目录: `storage.pluginDataDirectory(for: "ToolManager")`。
///
/// 记录为后台异步操作,不影响主流程性能。
actor ToolCallRecordStore: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-manager.records")

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// 批量写入缓冲区,减少 IO 操作。
    private var pendingRecords: [ToolCallRecordModel] = []
    private let maxBatchSize = 10

    private var flushTask: Task<Void, Never>?

    /// - Parameter databaseRootURL: 数据库根目录(`pluginDataDirectory(for:)` 的返回值)。
    init(databaseRootURL: URL) {
        // 确保目录存在
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)

        let schema = Schema([ToolCallRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("tool_calls.sqlite", isDirectory: false)
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            if Self.verbose {
                Self.logger.info("\(Self.t)初始化完成,数据库位于 \(storeURL.path)")
            }
        } catch {
            Self.logger.error("\(Self.t)创建失败,回退到内存容器：\(error.localizedDescription)")
            container = (try? ModelContainer(for: ToolCallRecordModel.self)) ?? (try! ModelContainer())
        }
        self.modelContainer = container
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = false
    }

    /// 初始化后启动定时刷新任务(由外部调用以避免 actor 初始化问题)。
    func startFlushTask() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 秒
                await self?.flush()
            }
        }
    }

    // MARK: - Public API

    /// 记录一次工具调用(后台异步写入,不影响主流程)。
    func record(
        toolName: String,
        toolDisplayName: String,
        turnID: UUID? = nil,
        conversationID: UUID,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date?,
        duration: Double?,
        argumentsJSON: String,
        resultContent: String,
        resultIsError: Bool,
        riskLevel: String,
        turnControl: String? = nil
    ) {
        let model = ToolCallRecordModel(
            id: UUID().uuidString,
            toolName: toolName,
            toolDisplayName: toolDisplayName,
            turnID: turnID?.uuidString,
            conversationID: conversationID.uuidString,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: completedAt,
            duration: duration,
            argumentsJSON: argumentsJSON,
            resultContent: String(resultContent.prefix(10_000)), // 限制结果大小
            resultIsError: resultIsError,
            riskLevel: riskLevel,
            turnControl: turnControl
        )

        pendingRecords.append(model)

        // 达到批量大小时立即刷新
        if pendingRecords.count >= maxBatchSize {
            Task { [weak self] in
                await self?.flush()
            }
        }
    }

    /// Fetch 一页记录。
    func fetchPage(
        limit: Int,
        beforeCreatedAt: Date? = nil,
        beforeID: String? = nil
    ) -> [ToolCallRecordDTO] {
        guard limit > 0 else { return [] }

        var descriptor: FetchDescriptor<ToolCallRecordModel>
        if let cursorDate = beforeCreatedAt, let cursorID = beforeID {
            descriptor = FetchDescriptor<ToolCallRecordModel>(
                predicate: #Predicate<ToolCallRecordModel> {
                    $0.createdAt < cursorDate ||
                    ($0.createdAt == cursorDate && $0.id < cursorID)
                },
                sortBy: [
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse),
                ]
            )
        } else {
            descriptor = FetchDescriptor<ToolCallRecordModel>(sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id, order: .reverse),
            ])
        }
        descriptor.fetchLimit = limit
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map { ToolCallRecordDTO(from: $0) }
    }

    /// 获取某会话的所有记录。
    func fetchRecords(for conversationID: UUID) -> [ToolCallRecordDTO] {
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.conversationID == conversationID.uuidString
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map { ToolCallRecordDTO(from: $0) }
    }

    /// 获取某个 AgentTurn 的全部工具调用,按开始时间升序返回。
    func fetchRecords(forTurnID turnID: UUID) -> [ToolCallRecordDTO] {
        flush()
        let turnIDString = turnID.uuidString
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.turnID == turnIDString
            },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map { ToolCallRecordDTO(from: $0) }
    }

    /// 记录总数。
    func count() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<ToolCallRecordModel>())) ?? 0
    }

    /// 删除指定记录。
    func delete(id: String) {
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for m in models { modelContext.delete(m) }
        try? modelContext.save()
    }

    /// 删除指定会话的所有记录。
    func deleteAll(for conversationID: UUID) {
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.conversationID == conversationID.uuidString
            }
        )
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for m in models { modelContext.delete(m) }
        try? modelContext.save()
    }

    /// 删除所有记录。
    func deleteAll() {
        let descriptor = FetchDescriptor<ToolCallRecordModel>()
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for m in models { modelContext.delete(m) }
        try? modelContext.save()
    }

    /// 获取工具调用统计(按工具名聚合)。
    func fetchToolStats() -> [ToolStats] {
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            sortBy: [SortDescriptor(\.toolName)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }

        // 按工具名聚合
        var statsMap: [String: ToolStatsAccumulator] = [:]
        for model in models {
            var acc = statsMap[model.toolName] ?? ToolStatsAccumulator()
            acc.totalCount += 1
            if model.resultIsError {
                acc.errorCount += 1
            }
            if let duration = model.duration {
                acc.totalDuration += duration
            }
            statsMap[model.toolName] = acc
        }

        return statsMap.map { name, acc in
            ToolStats(
                toolName: name,
                toolDisplayName: models.first(where: { $0.toolName == name })?.toolDisplayName ?? name,
                totalCount: acc.totalCount,
                errorCount: acc.errorCount,
                averageDuration: acc.totalCount > 0 ? acc.totalDuration / Double(acc.totalCount) : 0
            )
        }.sorted { $0.totalCount > $1.totalCount }
    }

    /// 获取每日工具调用统计。
    func fetchDailyCountSeries(days: Int = 14, endingAt date: Date = Date()) -> [DailyCountPoint] {
        guard days > 0 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today

        var points: [DailyCountPoint] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                continue
            }

            let descriptor = FetchDescriptor<ToolCallRecordModel>(
                predicate: #Predicate<ToolCallRecordModel> {
                    $0.createdAt >= day && $0.createdAt < nextDay
                }
            )
            let count = (try? modelContext.fetchCount(descriptor)) ?? 0
            points.append(DailyCountPoint(day: day, count: count))
        }
        return points
    }

    // MARK: - Private

    /// 刷新缓冲区中的记录到数据库。
    private func flush() {
        guard !pendingRecords.isEmpty else { return }

        let recordsToSave = pendingRecords
        pendingRecords.removeAll()

        for record in recordsToSave {
            modelContext.insert(record)
        }

        do {
            try modelContext.save()
            if Self.verbose {
                Self.logger.debug("\(Self.t)刷新 \(recordsToSave.count) 条记录")
            }
        } catch {
            Self.logger.error("\(Self.t)保存失败：\(error.localizedDescription)")
        }
    }
}

/// 每日统计点。
struct DailyCountPoint: Identifiable, Sendable {
    public var id: Date { day }
    public let day: Date
    public let count: Int
}

/// 工具调用统计结果。
struct ToolStats: Identifiable, Sendable {
    public var id: String { toolName }
    public let toolName: String
    public let toolDisplayName: String
    public let totalCount: Int
    public let errorCount: Int
    public let averageDuration: Double
}

/// 工具调用统计累加器(用于聚合计算)。
private struct ToolStatsAccumulator {
    var totalCount: Int = 0
    var errorCount: Int = 0
    var totalDuration: Double = 0
}
