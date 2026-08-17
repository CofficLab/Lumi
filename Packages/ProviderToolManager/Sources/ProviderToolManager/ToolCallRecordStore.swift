import Foundation
import SwiftData

/// 使用 SwiftData 持久化「工具调用」记录的后台存储服务。
///
/// 复刻自旧内核 `ToolManagerPlugin` 的 `ToolCallRecordStore`：
/// - 后台异步写入（批量缓冲 + 定时 flush），不影响主流程性能
/// - 记录为纯数据副本 `ToolCallRecord`，避免跨 actor 传递 managed 对象
///
/// 存储目录: 宿主通过 `StorageProviding.pluginDataDirectory(for:)` 提供。
public actor ToolCallRecordStore {
    private let modelContext: ModelContext

    /// 数据库根目录，允许 UI 在主线程读取以打开 Finder。
    nonisolated public let directory: URL

    /// 批量写入缓冲区，减少 IO 操作。
    private var pendingRecords: [ToolCallRecordModel] = []
    private var deletedConversationIDs: Set<String> = []
    private let maxBatchSize = 10

    private var flushTask: Task<Void, Never>?

    /// - Parameter databaseRootURL: 数据库根目录（`pluginDataDirectory(for:)` 的返回值）。
    public init(databaseRootURL: URL) {
        // 确保目录存在
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)

        self.directory = databaseRootURL

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
        } catch {
            // 建库失败时回退到内存容器，保证服务可用（与旧实现一致）。
            let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [memoryConfiguration]))
                ?? (try! ModelContainer())
        }
        self.modelContext = ModelContext(container)
        self.modelContext.autosaveEnabled = false
    }

    /// 初始化后启动定时刷新任务（由外部调用以避免 actor 初始化问题）。
    public func startFlushTask() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 秒
                await self?.flush()
            }
        }
    }

    /// 停止定时刷新任务（生命周期结束时调用）。
    public func stopFlushTask() {
        flushTask?.cancel()
        flushTask = nil
    }

    // MARK: - Public API

    /// 记录一次工具调用（后台异步写入，不影响主流程）。
    func record(
        toolCallID: String = "",
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
        resultJSON: String? = nil,
        resultIsError: Bool,
        riskLevel: String
    ) {
        guard !deletedConversationIDs.contains(conversationID.uuidString) else { return }
        let model = ToolCallRecordModel(
            id: UUID().uuidString,
            toolCallID: toolCallID.isEmpty ? nil : toolCallID,
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
            resultJSON: resultJSON,
            resultIsError: resultIsError,
            riskLevel: riskLevel
        )

        pendingRecords.append(model)

        // 达到批量大小时立即刷新
        if pendingRecords.count >= maxBatchSize {
            Task { [weak self] in
                await self?.flush()
            }
        }
    }

    /// 按原始 `ToolCall.id` 查询一条记录（尚未 flush 的缓冲记录也会先落库）。
    public func fetchRecord(forToolCallID toolCallID: String) -> ToolCallRecord? {
        flush()
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.toolCallID == toolCallID
            }
        )
        return try? modelContext.fetch(descriptor).first.map(Self.convert)
    }

    /// 查询某个 AgentTurn 的全部工具调用，按开始时间升序返回。
    public func fetchRecords(forTurnID turnID: UUID) -> [ToolCallRecord] {
        flush()
        let turnIDString = turnID.uuidString
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.turnID == turnIDString
            },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map(Self.convert)
    }

    /// 查询某个会话的全部记录，按开始时间倒序返回。
    public func fetchRecords(for conversationID: UUID) -> [ToolCallRecord] {
        flush()
        let conversationIDString = conversationID.uuidString
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.conversationID == conversationIDString
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map(Self.convert)
    }

    /// 记录总数。
    public func count() -> Int {
        flush()
        return (try? modelContext.fetchCount(FetchDescriptor<ToolCallRecordModel>())) ?? 0
    }

    /// 分页查询一页记录（按创建时间倒序；游标为「早于某条」语义）。
    ///
    /// 复刻旧版 `ToolManagerPlugin.ToolCallRecordStore.fetchPage`，供设置页
    /// 执行日志等 UI 分页加载。
    public func fetchPage(
        limit: Int,
        beforeCreatedAt: Date? = nil,
        beforeID: String? = nil
    ) -> [ToolCallRecord] {
        guard limit > 0 else { return [] }
        flush()

        var descriptor: FetchDescriptor<ToolCallRecordModel>
        if let cursorDate = beforeCreatedAt, let cursorID = beforeID {
            descriptor = FetchDescriptor<ToolCallRecordModel>(
                predicate: #Predicate<ToolCallRecordModel> {
                    $0.createdAt < cursorDate
                        || ($0.createdAt == cursorDate && $0.id < cursorID)
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
        return models.map(Self.convert)
    }

    /// 删除某个会话的全部记录，并阻止该会话后续写入。
    public func deleteAll(for conversationID: UUID) {
        deletedConversationIDs.insert(conversationID.uuidString)
        // 写后读屏障：先 flush，保证删除前已接受的记录不会在删除后被写回。
        flush()
        let conversationIDString = conversationID.uuidString
        let descriptor = FetchDescriptor<ToolCallRecordModel>(
            predicate: #Predicate<ToolCallRecordModel> {
                $0.conversationID == conversationIDString
            }
        )
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for model in models {
            modelContext.delete(model)
        }
        try? modelContext.save()
    }

    // MARK: - Flush

    /// 把缓冲区中的记录批量写入磁盘。
    func flush() {
        guard !pendingRecords.isEmpty else { return }
        let batch = pendingRecords
        pendingRecords.removeAll(keepingCapacity: true)
        for model in batch {
            modelContext.insert(model)
        }
        try? modelContext.save()
    }

    // MARK: - Conversion

    private static func convert(_ model: ToolCallRecordModel) -> ToolCallRecord {
        ToolCallRecord(
            id: model.id,
            toolCallID: model.toolCallID,
            toolName: model.toolName,
            toolDisplayName: model.toolDisplayName,
            turnID: model.turnID.flatMap(UUID.init(uuidString:)),
            conversationID: UUID(uuidString: model.conversationID) ?? UUID(),
            createdAt: model.createdAt,
            startedAt: model.startedAt,
            completedAt: model.completedAt,
            duration: model.duration,
            argumentsJSON: model.argumentsJSON,
            resultContent: model.resultContent,
            resultJSON: model.resultJSON,
            resultIsError: model.resultIsError,
            riskLevel: model.riskLevel
        )
    }
}
