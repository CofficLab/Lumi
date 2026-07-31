import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftData

/// Conversation storage service using SwiftData
///
/// Manages conversation persistence with SQLite database in plugin directory.
/// Thread-safe via Actor isolation, following `TaskStateManager` pattern.
public actor ConversationStore: SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation.store")

    // MARK: - Properties

    private let container: ModelContainer

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        self.container = try Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) throws -> ModelContainer {
        let schema = Schema([ConversationModel.self])
        let dbDir = databaseRootURL
        let dbURL = dbDir.appendingPathComponent("conversations.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationStore 数据库目录: \(error.localizedDescription)")
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
                Self.logger.error("\(Self.t)打开对话数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        // 重建尝试
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationStore 数据库重建失败: \(error.localizedDescription)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal"),
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
                Self.logger.error("\(Self.t)隔离对话数据库文件失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create

    /// Create a new conversation with specific ID
    @discardableResult
    func createConversation(id: UUID, title: String?, preview: String = "", createdAt: Date = Date(), providerID: String? = nil, modelName: String? = nil, projectPath: String? = nil) throws -> ConversationModel {
        let context = ModelContext(container)
        let now = createdAt.timeIntervalSince1970
        let model = ConversationModel(
            id: id.uuidString,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            preview: preview,
            createdAt: now,
            updatedAt: now,
            providerId: providerID,
            modelName: modelName,
            projectPath: projectPath
        )
        context.insert(model)
        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(title ?? "nil"), 供应商：\(providerID ?? "nil"), 模型：\(modelName ?? "nil"), 项目：\(projectPath ?? "nil")")
        }

        return model
    }

    // MARK: - Migration Import

    /// 批量导入历史会话(v4 迁移专用)
    ///
    /// 用于 v4 → v5 迁移:把 `LegacyDataProviding` 读出的 `LumiConversationSummary`
    /// 批量写入 v5 库,保留全部字段(verbosity/language/model/projectPath 等),
    /// 单次 `save` 保证原子性。按 id 去重:已存在的会话跳过,避免重复导入。
    ///
    /// - Parameter summaries: 待导入的会话列表。
    /// - Returns: 实际新增的数量(跳过已存在的)。
    @discardableResult
    func importSummaries(_ summaries: [LumiConversationSummary]) throws -> Int {
        guard !summaries.isEmpty else { return 0 }

        let context = ModelContext(container)

        // 查出已存在的 id 集合,用于去重
        let existingIDs: Set<String> = {
            let descriptor = FetchDescriptor<ConversationModel>()
            let models = (try? context.fetch(descriptor)) ?? []
            return Set(models.map { $0.id })
        }()

        var inserted = 0
        for summary in summaries {
            let idString = summary.id.uuidString
            guard !existingIDs.contains(idString) else { continue }
            context.insert(ConversationModel.from(summary: summary))
            inserted += 1
        }

        guard inserted > 0 else { return 0 }

        do {
            try context.save()
            if Self.verbose {
                Self.logger.info("\(Self.t)迁移导入 \(inserted) 条历史会话")
            }
            return inserted
        } catch {
            Self.logger.error("\(Self.t)迁移导入会话失败：\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Read

    /// Fetch all conversations, sorted by updatedAt descending
    func fetchConversations() -> [LumiConversationSummary] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<ConversationModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let models = try context.fetch(descriptor)
            return models.compactMap { $0.toLumiConversationSummary() }
        } catch {
            Self.logger.error("\(Self.t)查询对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Fetch one conversation page using a keyset cursor.
    ///
    /// The cursor is the last item from the previous page. Keyset pagination
    /// avoids materializing all earlier rows as the conversation table grows.
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil
    ) -> [LumiConversationSummary] {
        guard limit > 0 else { return [] }

        let context = ModelContext(container)
        let cursorTimestamp = beforeUpdatedAt?.timeIntervalSince1970
        let cursorID = beforeID?.uuidString
        var descriptor: FetchDescriptor<ConversationModel>

        if let cursorTimestamp, let cursorID {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.updatedAt < cursorTimestamp ||
                    ($0.updatedAt == cursorTimestamp && $0.id < cursorID)
                },
                sortBy: [
                    SortDescriptor(\.updatedAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse),
                ]
            )
        } else {
            descriptor = FetchDescriptor<ConversationModel>(
                sortBy: [
                    SortDescriptor(\.updatedAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse),
                ]
            )
        }

        descriptor.fetchLimit = limit

        do {
            let models = try context.fetch(descriptor)
            return models.compactMap { $0.toLumiConversationSummary() }
        } catch {
            Self.logger.error("\(Self.t)查询对话分页失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Count conversations without materializing their summaries.
    func conversationCount() -> Int {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ConversationModel>()

        do {
            return try context.fetchCount(descriptor)
        } catch {
            Self.logger.error("\(Self.t)统计对话数量失败：\(error.localizedDescription)")
            return 0
        }
    }

    /// Build a recent daily conversation-count series with bounded count queries.
    func fetchDailyCountSeries(days: Int = 14, endingAt date: Date = Date()) -> ConversationDailyCountSeries {
        guard days > 0 else { return ConversationDailyCountSeries(points: []) }

        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let points = (0..<days).compactMap { offset -> ConversationDailyCountPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let startTimestamp = day.timeIntervalSince1970
            let endTimestamp = nextDay.timeIntervalSince1970
            let descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.createdAt >= startTimestamp && $0.createdAt < endTimestamp
                }
            )
            let count = (try? context.fetchCount(descriptor)) ?? 0
            return ConversationDailyCountPoint(day: day, count: count)
        }
        return ConversationDailyCountSeries(points: points)
    }

    /// Fetch a single conversation by ID
    func fetchConversation(id: UUID) -> LumiConversationSummary? {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        return try? context.fetch(descriptor).first?.toLumiConversationSummary()
    }

    // MARK: - Update

    /// Update conversation title
    func updateTitle(id: UUID, title: String) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新标题")
    }

    /// Update conversation preview
    func updatePreview(id: UUID, preview: String) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.preview = preview
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新预览")
    }

    /// Update conversation timestamp (mark as active)
    func touchConversation(id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新活动时间")
    }

    /// Update conversation provider and model
    func updateConversationProvider(id: UUID, providerID: String, modelName: String?) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.providerId = providerID
        model.modelName = modelName
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新供应商")
    }

    /// Update conversation response preferences
    func updateConversationPreferences(
        id: UUID,
        verbosity: LumiResponseVerbosity? = nil,
        reasoningEffort: LumiReasoningEffort? = nil
    ) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        if let verbosity {
            model.verbosityRaw = verbosity.rawValue
        }
        if let reasoningEffort {
            model.reasoningEffortRaw = reasoningEffort.rawValue
        }
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新对话偏好")
    }

    /// Update conversation order
    func updateOrder(id: UUID, order: Int) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.order = order
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新排序")
    }

    /// 批量更新一组对话的关联项目路径。
    ///
    /// 用于「当前项目切换时，把所有空对话迁移到新项目」：一次查询、单次 `save`，
    /// 避免逐条更新的多次磁盘写入。传入空数组时直接返回 `false`。
    ///
    /// - Parameters:
    ///   - conversationIDs: 待迁移的对话 ID 列表。
    ///   - projectPath: 新的项目路径（nil 表示取消关联）。
    /// - Returns: 至少更新一条返回 `true`，否则 `false`。
    @discardableResult
    func updateProjectPath(for conversationIDs: [UUID], projectPath: String?) -> Bool {
        guard !conversationIDs.isEmpty else { return false }

        let context = ModelContext(container)
        let idStrings = conversationIDs.map { $0.uuidString }

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { idStrings.contains($0.id) }
        )

        guard let models = try? context.fetch(descriptor), !models.isEmpty else {
            return false
        }

        for model in models {
            model.projectPath = projectPath
        }

        return save(context, operation: "批量更新对话项目路径")
    }

    /// Fetch pinned conversations, returning their IDs sorted by order.
    func fetchPinnedConversationIDs() -> [(UUID, Int)] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.order == 0 },
            sortBy: [SortDescriptor(\.order)]
        )

        do {
            let models = try context.fetch(descriptor)
            return models.compactMap { model in
                guard let uuid = UUID(uuidString: model.id) else { return nil }
                return (uuid, model.order ?? LumiConversationSummary.defaultOrder)
            }
        } catch {
            return []
        }
    }

    // MARK: - Delete

    /// Delete a conversation by ID
    func deleteConversation(id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        context.delete(model)
        return save(context, operation: "删除对话")
    }

    // MARK: - Private

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            Self.logger.error("\(Self.t)\(operation)失败：\(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Database Root URL

public extension ConversationStore {
    /// Default database root URL (temporary directory)
    static var defaultDatabaseRootURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/ConversationStore")
    }
}
