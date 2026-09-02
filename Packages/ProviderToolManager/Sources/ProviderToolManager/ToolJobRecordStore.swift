import Foundation
import SwiftData

/// 使用独立 `tool_jobs.sqlite` 保存可恢复 Tool Job 状态的后台存储服务。
public actor ToolJobRecordStore {
    private static let maxOutputBytes = 64 * 1024

    private let modelContext: ModelContext
    private var deletedConversationIDs: Set<String> = []
    nonisolated public let directory: URL

    public init(databaseRootURL: URL) {
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)
        self.directory = databaseRootURL

        let schema = Schema([ToolJobRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("tool_jobs.sqlite", isDirectory: false)
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
            let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [memoryConfiguration]))
                ?? (try! ModelContainer())
        }
        self.modelContext = ModelContext(container)
        self.modelContext.autosaveEnabled = false
    }

    /// 创建或更新一条 Job 快照。按 Job ID 幂等写入。
    public func upsert(_ record: ToolJobRecord) {
        guard !deletedConversationIDs.contains(record.conversationID.uuidString) else { return }
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.id == record.id }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.update(with: record)
        } else {
            modelContext.insert(ToolJobRecordModel(record: record))
        }
        try? modelContext.save()
    }

    public func fetchRecord(forJobID jobID: String) -> ToolJobRecord? {
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.id == jobID }
        )
        return (try? modelContext.fetch(descriptor).first)?.flatMap { $0.value() }
    }

    public func fetchNonTerminalJobs() -> [ToolJobRecord] {
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.compactMap { record in
            guard let value = record.value(), !value.status.isTerminal else { return nil }
            return value
        }
    }

    /// 返回全部 Job 快照，供执行管理器在启动时恢复幂等索引。
    public func fetchAllJobs() -> [ToolJobRecord] {
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.compactMap { $0.value() }
    }

    public func fetchJobs(forConversationID conversationID: UUID) -> [ToolJobRecord] {
        let conversationIDString = conversationID.uuidString
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.conversationID == conversationIDString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.compactMap { $0.value() }
    }

    public func fetchJobs(forTurnID turnID: UUID) -> [ToolJobRecord] {
        let turnIDString = turnID.uuidString
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.turnID == turnIDString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.compactMap { $0.value() }
    }

    public func deleteAll(for conversationID: UUID) {
        let conversationIDString = conversationID.uuidString
        deletedConversationIDs.insert(conversationIDString)
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.conversationID == conversationIDString }
        )
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for model in models {
            modelContext.delete(model)
        }
        try? modelContext.save()
    }

    /// 统一截断输出尾部，避免失控命令耗尽 Job 数据库。
    public static func boundedOutput(_ output: String) -> String {
        let data = Data(output.utf8)
        return String(decoding: data.suffix(maxOutputBytes), as: UTF8.self)
    }
}
