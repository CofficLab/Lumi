import Foundation
import KitLLM
import os
import ProviderConversation
import LumiLoggingKit
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

    /// 每日对话条数账本。
    ///
    /// 统计与「会话是否还在库里」解耦：清理旧对话不会让历史计数塌陷。
    /// 详见 `ConversationCountLedger`。
    private let ledger: ConversationCountLedger

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        let container = try Self.makeContainer(databaseRootURL: databaseRootURL)
        self.container = container
        let ledger = ConversationCountLedger(
            fileURL: databaseRootURL.appendingPathComponent(ConversationCountLedger.fileName)
        )
        self.ledger = ledger
        // 必须在任何删除发生之前完成对齐：账本一旦记下「某天有 N 个对话」，
        // 后续删除会话就不会再改动它。若推迟到用户打开统计面板才回填，
        // 这期间被清理掉的历史就永远补不回来了。
        Self.seedLedger(ledger: ledger, container: container)
    }

    /// 用会话表的现状回填账本（仅首次建立账本时执行）。
    private static func seedLedger(ledger: ConversationCountLedger, container: ModelContainer) {
        // 先读盘再判断：否则每次启动都会认为账本是空的，把整张会话表重扫一遍。
        ledger.load()
        guard !ledger.isSeededFromTable else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ConversationModel>()
        guard let models = try? context.fetch(descriptor) else { return }
        var buckets: [ConversationCountLedger.BucketKey: Int] = [:]
        for model in models {
            let key = ConversationCountLedger.BucketKey(
                day: ConversationCountLedger.dayKey(for: Date(timeIntervalSince1970: model.createdAt)),
                projectPath: model.projectPath,
                isChildConversation: model.parentConversationID != nil
            )
            buckets[key, default: 0] += 1
        }
        ledger.mergeSeeded(tableCounts: buckets)
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
    func createConversation(id: UUID, title: String?, preview: String = "", createdAt: Date = Date(), verbosity: ResponseVerbosity? = nil, providerID: String? = nil, modelName: String? = nil, projectPath: String? = nil, parentConversationID: UUID? = nil, reasoningEffort: ReasoningEffort? = nil, automationLevel: AutomationLevel? = nil) throws -> ConversationModel {
        let modelID = providerID.flatMap { provider in
            modelName.flatMap { LLMModelID(providerID: provider, modelID: $0)?.rawValue }
        }
        return try createConversation(
            id: id,
            title: title,
            preview: preview,
            createdAt: createdAt,
            verbosity: verbosity,
            modelID: modelID.flatMap { LLMModelID(rawValue: $0)?.rawValue },
            projectPath: projectPath,
            parentConversationID: parentConversationID,
            reasoningEffort: reasoningEffort,
            automationLevel: automationLevel
        )
    }

    @discardableResult
    func createConversation(
        id: UUID,
        title: String?,
        preview: String = "",
        createdAt: Date = Date(),
        verbosity: ResponseVerbosity? = nil,
        modelID: String?,
        projectPath: String? = nil,
        parentConversationID: UUID? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        automationLevel: AutomationLevel? = nil
    ) throws -> ConversationModel {
        let context = ModelContext(container)
        let now = createdAt.timeIntervalSince1970
        let model = ConversationModel(
            id: id.uuidString,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            preview: preview,
            createdAt: now,
            updatedAt: now,
            verbosityRaw: verbosity?.rawValue,
            reasoningEffortRaw: reasoningEffort?.rawValue,
            automationLevelRaw: automationLevel?.rawValue,
            modelID: modelID,
            projectPath: projectPath,
            parentConversationID: parentConversationID?.uuidString
        )
        context.insert(model)
        try context.save()

        // 记入统计账本：计数独立于会话行存在，删除会话不会让它回落。
        recordCount(createdAt: createdAt, projectPath: projectPath, parentConversationID: parentConversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(title ?? "nil"), 模型 ID：\(modelID ?? "nil"), 项目：\(projectPath ?? "nil")")
        }

        return model
    }

    /// 把一次会话创建记入统计账本。
    private func recordCount(
        createdAt: Date,
        projectPath: String?,
        parentConversationID: UUID?
    ) {
        ledger.apply([
            ConversationCountLedger.Increment(
                day: ConversationCountLedger.dayKey(for: createdAt),
                projectPath: projectPath,
                isChildConversation: parentConversationID != nil,
                count: 1
            )
        ])
    }

    /// 将旧 SwiftData providerId + modelName 行一次性折叠为单一 modelID。
    @discardableResult
    func migrateLegacyModelSelections() -> Int {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.providerId != nil || $0.modelName != nil }
        )
        guard let models = try? context.fetch(descriptor), !models.isEmpty else { return 0 }
        var migrated = 0
        for model in models {
            if model.modelID == nil,
               let providerID = model.providerId,
               let modelName = model.modelName,
               let selectionID = LLMModelID(providerID: providerID, modelID: modelName) {
                model.modelID = selectionID.rawValue
                migrated += 1
            }
            model.providerId = nil
            model.modelName = nil
        }
        guard save(context, operation: "迁移对话模型 ID") else { return 0 }
        return migrated
    }

    // MARK: - Migration Import

    /// 批量导入历史会话(v4 迁移专用)
    ///
    /// 用于 v4 → v5 迁移:把 v4 旧库读出的 `LumiConversationSummary`
    /// 批量写入 v5 库,保留全部字段(verbosity/language/model/projectPath 等),
    /// 单次 `save` 保证原子性。按 id 去重:已存在的会话跳过,避免重复导入。
    ///
    /// - Parameter summaries: 待导入的会话列表。
    /// - Returns: 实际新增的数量(跳过已存在的)。
    @discardableResult
    func importSummaries(_ summaries: [ConversationSummary]) throws -> Int {
        guard !summaries.isEmpty else { return 0 }

        let context = ModelContext(container)

        // 查出已存在的 id 集合,用于去重
        let existingIDs: Set<String> = {
            let descriptor = FetchDescriptor<ConversationModel>()
            let models = (try? context.fetch(descriptor)) ?? []
            return Set(models.map { $0.id })
        }()

        var inserted = 0
        var increments: [ConversationCountLedger.Increment] = []
        for summary in summaries {
            let idString = summary.id.uuidString
            guard !existingIDs.contains(idString) else { continue }
            context.insert(ConversationModel.from(summary: summary))
            increments.append(
                ConversationCountLedger.Increment(
                    day: ConversationCountLedger.dayKey(for: summary.createdAt),
                    projectPath: summary.projectPath,
                    isChildConversation: summary.parentConversationID != nil,
                    count: 1
                )
            )
            inserted += 1
        }

        guard inserted > 0 else { return 0 }

        do {
            try context.save()
            // 迁移来的历史会话同样计入账本，否则旧数据不会出现在统计里。
            ledger.apply(increments)
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

    /// Fetch one conversation page using a keyset cursor.
    ///
    /// The cursor is the last item from the previous page. Keyset pagination
    /// avoids materializing all earlier rows as the conversation table grows.
    ///
    /// - Note: 读取失败会被折叠成空数组；需要区分「读取失败」与「空库」的调用方
    ///   应改用 `loadConversationPage`。
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool = false
    ) -> [ConversationSummary] {
        do {
            return try loadConversationPage(
                limit: limit,
                beforeUpdatedAt: beforeUpdatedAt,
                beforeID: beforeID,
                includingChildConversations: includingChildConversations
            )
        } catch {
            Self.logger.error("\(Self.t)查询对话分页失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Fetch one page, throwing storage errors instead of folding them into `[]`.
    func loadConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool = false
    ) throws -> [ConversationSummary] {
        guard limit > 0 else { return [] }

        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        backfillSortKeys(in: context)
        let cursorKey: Int64? = {
            guard let beforeUpdatedAt, let beforeID else { return nil }
            return ConversationModel.makeSortKey(
                date: beforeUpdatedAt.timeIntervalSince1970,
                id: beforeID.uuidString
            )
        }()
        var descriptor: FetchDescriptor<ConversationModel>

        // Keyset 必须与列表排序同基准：`sortKey` 降序。
        // 旧实现按 createdAt 取页、再按 lastMessageAt 内存重排，会把
        // 「创建早但最近活跃」的会话整条漏掉，并在下一页重复返回。
        if let cursorKey {
            if includingChildConversations {
                descriptor = FetchDescriptor<ConversationModel>(
                    predicate: #Predicate<ConversationModel> {
                        $0.sortKey < cursorKey
                    },
                    sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<ConversationModel>(
                    predicate: #Predicate<ConversationModel> {
                        $0.sortKey < cursorKey &&
                        $0.parentConversationID == nil
                    },
                    sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
                )
            }
        } else {
            if includingChildConversations {
                descriptor = FetchDescriptor<ConversationModel>(
                    sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<ConversationModel>(
                    predicate: #Predicate<ConversationModel> { $0.parentConversationID == nil },
                    sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
                )
            }
        }

        descriptor.fetchLimit = limit

        do {
            let models = try context.fetch(descriptor)
            // 数据库已按 `sortKey` 排好，直接映射，避免二次排序改变顺序。
            return models.compactMap { $0.toLumiConversationSummary() }
        } catch {
            Self.logger.error("\(Self.t)查询对话分页失败：\(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch one page of conversations filtered by project path.
    ///
    /// - Note: 读取失败会被折叠成空数组；需要区分失败的调用方应改用
    ///   `loadConversationPage(projectPath:)`。
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool = false,
        projectPath: String
    ) -> [ConversationSummary] {
        do {
            return try loadConversationPage(
                limit: limit,
                beforeUpdatedAt: beforeUpdatedAt,
                beforeID: beforeID,
                includingChildConversations: includingChildConversations,
                projectPath: projectPath
            )
        } catch {
            Self.logger.error("\(Self.t)按项目查询对话分页失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Fetch one project-scoped page, throwing storage errors instead of `[]`.
    func loadConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool = false,
        projectPath: String
    ) throws -> [ConversationSummary] {
        guard limit > 0 else { return [] }

        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        backfillSortKeys(in: context)
        let cursorKey: Int64? = {
            guard let beforeUpdatedAt, let beforeID else { return nil }
            return ConversationModel.makeSortKey(
                date: beforeUpdatedAt.timeIntervalSince1970,
                id: beforeID.uuidString
            )
        }()
        var descriptor: FetchDescriptor<ConversationModel>

        if let cursorKey {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.sortKey < cursorKey &&
                    $0.projectPath == projectPath &&
                    (includingChildConversations || $0.parentConversationID == nil)
                },
                sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.projectPath == projectPath &&
                    (includingChildConversations || $0.parentConversationID == nil)
                },
                sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit

        do {
            let models = try context.fetch(descriptor)
            return models.compactMap { $0.toLumiConversationSummary() }
        } catch {
            Self.logger.error("\(Self.t)按项目查询对话分页失败：\(error.localizedDescription)")
            throw error
        }
    }

    /// 返回指定项目下、且在给定时间点之后仍有活动的会话 ID。
    ///
    /// 只取 ID 不物化摘要：消息统计只需要一个会话集合，载整张摘要表纯属浪费。
    func conversationIDs(projectPath: String, updatedSince: Date? = nil) -> [String] {
        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        let timestamp = updatedSince?.timeIntervalSince1970
        let descriptor: FetchDescriptor<ConversationModel>
        if let timestamp {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.projectPath == projectPath && $0.updatedAt >= timestamp
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> { $0.projectPath == projectPath },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }

        do {
            return try context.fetch(descriptor).map(\.id)
        } catch {
            Self.logger.error("\(Self.t)按项目查询会话 ID 失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Count conversations without materializing their summaries.
    func conversationCount(includingChildConversations: Bool = true) -> Int {        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        let descriptor: FetchDescriptor<ConversationModel> = includingChildConversations
            ? FetchDescriptor<ConversationModel>()
            : FetchDescriptor<ConversationModel>(predicate: #Predicate<ConversationModel> { $0.parentConversationID == nil })

        do {
            return try context.fetchCount(descriptor)
        } catch {
            Self.logger.error("\(Self.t)统计对话数量失败：\(error.localizedDescription)")
            return 0
        }
    }

    func conversationCount(projectPath: String?, includingChildConversations: Bool = true) -> Int {
        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        let descriptor: FetchDescriptor<ConversationModel>
        if let projectPath {
            descriptor = FetchDescriptor<ConversationModel>(predicate: #Predicate<ConversationModel> {
                $0.projectPath == projectPath &&
                (includingChildConversations || $0.parentConversationID == nil)
            })
        } else {
            descriptor = includingChildConversations
                ? FetchDescriptor<ConversationModel>()
                : FetchDescriptor<ConversationModel>(predicate: #Predicate<ConversationModel> { $0.parentConversationID == nil })
        }

        do {
            return try context.fetchCount(descriptor)
        } catch {
            Self.logger.error("按项目统计对话失败：\(error.localizedDescription)")
            return 0
        }
    }

    /// 不同项目路径的数量（仅统计 projectPath 非空、顶层对话）。
    ///
    /// 用于判断「当前项目」筛选入口是否有意义：当全库顶层对话只来自 ≤1 个项目时，
    /// 「全部对话」即等于该项目，筛选冗余。SwiftData 无原生 DISTINCT，
    /// 故用单属性扫描 + 内存去重（仅取 projectPath 字段，开销低）。
    func conversationProjectCount() -> Int {
        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        var descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> {
                $0.projectPath != nil && $0.parentConversationID == nil
            }
        )
        descriptor.propertiesToFetch = [\.projectPath]
        do {
            let models = try context.fetch(descriptor)
            return Set(models.compactMap { $0.projectPath }).count
        } catch {
            Self.logger.error("\(Self.t)统计不同项目数失败：\(error.localizedDescription)")
            return 0
        }
    }

    /// Build a recent daily conversation-count series.
    ///
    /// 数据来自**统计账本**而非会话表：会话被清理（删除 7/30 天前的对话）后，
    /// 历史计数依然保留，曲线不会塌陷。详见 `ConversationCountLedger`。
    ///
    /// - Parameters:
    ///   - days: 序列长度（向前回溯的天数）。
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    ///   - endingAt: 序列的最后一天。
    func fetchDailyCountSeries(
        days: Int = 14,
        projectPath: String? = nil,
        includingChildConversations: Bool = true,
        endingAt date: Date = Date()
    ) -> ConversationDailyCountSeries {
        guard days > 0 else { return ConversationDailyCountSeries(points: []) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let dailyCounts = ledger.dailyCounts(
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        )
        let points = (0..<days).compactMap { offset -> ConversationDailyCountPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            let count = dailyCounts[ConversationCountLedger.dayKey(for: day)] ?? 0
            return ConversationDailyCountPoint(day: day, count: count)
        }
        return ConversationDailyCountSeries(points: points)
    }

    /// 查找「创建于 `cutoff` 之前」的对话 ID。
    ///
    /// - Parameters:
    ///   - cutoff: 时间分界点；`createdAt` 早于它的会话命中。
    ///   - projectPath: 只查该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    func conversationIDs(
        createdBefore cutoff: Date,
        projectPath: String? = nil,
        includingChildConversations: Bool = true
    ) -> [UUID] {
        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        let cutoffTimestamp = cutoff.timeIntervalSince1970

        let descriptor: FetchDescriptor<ConversationModel>
        if let projectPath {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.createdAt < cutoffTimestamp &&
                    $0.projectPath == projectPath &&
                    (includingChildConversations || $0.parentConversationID == nil)
                }
            )
        } else {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.createdAt < cutoffTimestamp &&
                    (includingChildConversations || $0.parentConversationID == nil)
                }
            )
        }

        do {
            return try context.fetch(descriptor).compactMap { UUID(uuidString: $0.id) }
        } catch {
            Self.logger.error("\(Self.t)查询待清理对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 统计「创建于 `cutoff` 之前」的对话数量。
    ///
    /// - Parameters:
    ///   - cutoff: 时间分界点；`createdAt` 早于它的会话命中。
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String? = nil,
        includingChildConversations: Bool = true
    ) -> Int {
        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        let cutoffTimestamp = cutoff.timeIntervalSince1970

        let descriptor: FetchDescriptor<ConversationModel>
        if let projectPath {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.createdAt < cutoffTimestamp &&
                    $0.projectPath == projectPath &&
                    (includingChildConversations || $0.parentConversationID == nil)
                }
            )
        } else {
            descriptor = FetchDescriptor<ConversationModel>(
                predicate: #Predicate<ConversationModel> {
                    $0.createdAt < cutoffTimestamp &&
                    (includingChildConversations || $0.parentConversationID == nil)
                }
            )
        }

        do {
            return try context.fetchCount(descriptor)
        } catch {
            Self.logger.error("\(Self.t)统计待清理对话失败：\(error.localizedDescription)")
            return 0
        }
    }

    /// Fetch a single conversation by ID
    func fetchConversation(id: UUID) -> ConversationSummary? {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        return try? context.fetch(descriptor).first?.toLumiConversationSummary()
    }

    /// 返回仍然**没有标题**的对话 ID。
    ///
    /// ## 为什么判定条件是空串
    ///
    /// 「无标题」在存储层就是空串：`ConversationModel.title` 是**非可选** `String`，
    /// 而所有写入路径都会先 trim（`createConversation` / `updateTitle`），
    /// 因此库里不可能存在纯空白标题，`title == ""` 就是完整的「无标题」判定。
    ///
    /// ## 为什么必须走存储层
    ///
    /// 内存里的会话摘要只是一个**有界窗口**（只保留最近的一部分），
    /// 历史遗留的无标题对话很可能不在其中。按 ID 直接查库才能覆盖全量。
    ///
    /// ## 为什么排除子代理对话
    ///
    /// 子代理对话不进列表（列表只显示顶层对话），给它们补标题没有用户价值，
    /// 反而会让每次启动都重复处理同一批子对话。
    func untitledConversationIDs(limit: Int) -> [UUID] {
        guard limit > 0 else { return [] }

        let context = ModelContext(container)
        normalizeEmptyParentConversationIDs(in: context)
        var descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> {
                $0.title == "" && ($0.parentConversationID == nil || $0.parentConversationID == "")
            }
        )
        descriptor.fetchLimit = limit

        do {
            return try context.fetch(descriptor).compactMap { UUID(uuidString: $0.id) }
        } catch {
            Self.logger.error("\(Self.t)查询无标题对话失败：\(error.localizedDescription)")
            return []
        }
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

    /// Update conversation last message timestamp (when a new message is received)
    func updateLastMessageAt(id: UUID, messageDate: Date) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.lastMessageAt = messageDate.timeIntervalSince1970
        model.sortKey = ConversationModel.makeSortKey(
            date: messageDate.timeIntervalSince1970,
            id: idString
        )
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新最后消息时间")
    }

    /// Legacy update entry point; new callers should persist modelID directly.
    func updateConversationProvider(id: UUID, providerID: String, modelName: String?) -> Bool {
        let modelID = modelName.flatMap { LLMModelID(providerID: providerID, modelID: $0)?.rawValue }
        return updateConversationModelID(modelID, for: id)
    }

    func updateConversationModelID(_ modelID: String?, for id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.modelID = modelID.flatMap { LLMModelID(rawValue: $0)?.rawValue }
        model.providerId = nil
        model.modelName = nil
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新模型 ID")
    }

    /// Update conversation response preferences
    func updateConversationPreferences(
        id: UUID,
        verbosity: ResponseVerbosity? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        setReasoningEffortToNil: Bool = false,
        automationLevel: AutomationLevel? = nil
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
        if setReasoningEffortToNil {
            model.reasoningEffortRaw = nil
        }
        if let automationLevel {
            model.automationLevelRaw = automationLevel.rawValue
        }
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新对话偏好")
    }

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

    // MARK: - Delete

    /// Delete a conversation by ID
    func deleteConversation(id: UUID) -> Bool {
        deleteConversations(ids: [id])
    }

    /// Return the conversation and all descendant Agent conversations.
    func conversationIDsToDelete(id: UUID) -> [UUID] {
        guard let models = try? ModelContext(container).fetch(FetchDescriptor<ConversationModel>()) else {
            return [id]
        }

        var ids = [id.uuidString]
        var changed = true
        while changed {
            changed = false
            for model in models where !ids.contains(model.id) {
                guard let parentID = model.parentConversationID,
                      ids.contains(parentID) else { continue }
                ids.append(model.id)
                changed = true
            }
        }
        return ids.compactMap(UUID.init(uuidString:))
    }

    /// Delete a set of conversations in one SwiftData transaction.
    @discardableResult
    func deleteConversations(ids: [UUID]) -> Bool {
        guard !ids.isEmpty else { return false }
        let context = ModelContext(container)
        let idStrings = ids.map(\.uuidString)

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { idStrings.contains($0.id) }
        )

        guard let models = try? context.fetch(descriptor), !models.isEmpty else {
            return false
        }

        for model in models { context.delete(model) }
        return save(context, operation: "删除对话")
    }

    // MARK: - Private

    /// Older stores may encode an unset optional string as an empty string.
    /// Normalize those values so root-conversation predicates remain compatible.
    @discardableResult
    private func normalizeEmptyParentConversationIDs(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.parentConversationID == "" }
        )
        guard let models = try? context.fetch(descriptor), !models.isEmpty else { return 0 }
        for model in models {
            model.parentConversationID = nil
        }
        try? context.save()
        return models.count
    }

    /// 旧库新增 `sortKey` 列后为默认值 0；用最后消息时间（缺失时 createdAt）回填。
    /// 时间戳恒大于 0，因此 0 可安全作为「未回填」哨兵。
    private func backfillSortKeys(in context: ModelContext) {
        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.sortKey == 0 }
        )
        guard let models = try? context.fetch(descriptor), !models.isEmpty else { return }
        for model in models {
            model.sortKey = ConversationModel.makeSortKey(
                date: model.lastMessageAt ?? model.createdAt,
                id: model.id
            )
        }
        try? context.save()
    }

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
