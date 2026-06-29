import Foundation
import SwiftData
import SuperLogKit
import os

/// AutoTask 插件的状态管理器
///
/// 通过 SwiftData 管理任务的增删改查。
/// 使用 Actor 模式确保线程安全，参考 `CacheManager` 模板。
public actor TaskStateManager: SuperLog {
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose: Bool = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "autotask.state-manager")

    // MARK: - Singleton

    public static let shared = TaskStateManager()

    // MARK: - Properties

    private let container: ModelContainer

    /// 单个会话最大任务数
    nonisolated static let maxTasksPerConversation = 50

    /// 单个会话连续无感自动续聊的最大次数，防止 LLM 卡住时空转。
    nonisolated static let maxAutomaticContinuations = 5

    /// 内存态（非持久化）：标记某会话即将进入一次无感自动续聊轮次。
    ///
    /// 由 `AutoTaskTurnCheckRuntime` 在触发续聊前置位，由
    /// `TaskContextChatMiddleware` 在注入该轮 system prompt 时消费，
    /// 消费即清除，避免后续普通轮次误判。
    private var pendingContinuationConversationIDs: Set<String> = []

    /// 内存态（非持久化）：记录每个会话连续自动续聊的次数。
    ///
    /// 当 LLM 在该会话中调用 `update_task` 主动推进任务时计数归零；
    /// 超过 `maxAutomaticContinuations` 后不再自动续聊。
    private var continuationCountsByConversationID: [String: Int] = [:]

    // MARK: - Initialization

    private init() {
        self.container = Self.makeContainer(databaseRootURL: AutoTaskPlugin.configuration.databaseDirectory())
    }

    init(databaseRootURL: URL) {
        self.container = Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) -> ModelContainer {
        let schema = Schema([TaskItem.self])
        let dbDir = databaseRootURL.appendingPathComponent("AutoTaskPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("tasks.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)创建任务数据库目录失败：\(error.localizedDescription)")
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
                Self.logger.error("\(Self.t)打开任务数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)重建任务数据库失败，使用临时内存存储：\(error.localizedDescription)")
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
            preconditionFailure("Could not create in-memory AutoTaskPlugin ModelContainer: \(error)")
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
                Self.logger.error("\(Self.t)隔离任务数据库文件失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create

    /// 创建单个任务
    @discardableResult
    func createTask(
        conversationId: String,
        title: String,
        detail: String? = nil,
        order: Int = 0
    ) throws -> TaskItem {
        let context = ModelContext(container)
        let task = TaskItem(
            conversationId: conversationId,
            title: title,
            detail: detail,
            order: order
        )
        context.insert(task)
        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)创建任务：[\(order)] \(title)")
        }

        return task
    }

    /// 批量创建任务（用于一次性拆解后批量写入）
    @discardableResult
    func createTasks(conversationId: String, items: [(title: String, detail: String?)]) throws -> [TaskItem] {
        let context = ModelContext(container)

        // 先清除该会话的所有旧任务
        try deleteAllForConversation(conversationId, context: context, saveImmediately: false)

        let limitedItems = items.prefix(Self.maxTasksPerConversation)

        var created: [TaskItem] = []
        for (index, item) in limitedItems.enumerated() {
            let task = TaskItem(
                conversationId: conversationId,
                title: item.title,
                detail: item.detail,
                order: index + 1
            )
            if index == 0 {
                task.status = .inProgress
                task.updatedAt = Date().timeIntervalSince1970
            }
            context.insert(task)
            created.append(task)
        }

        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)批量创建 \(created.count) 个任务 (会话: \(conversationId))")
        }

        return created
    }

    // MARK: - Append

    /// 追加任务到已有任务列表末尾（不清除旧任务）
    @discardableResult
    func appendTasks(conversationId: String, items: [(title: String, detail: String?)]) throws -> [TaskItem] {
        let context = ModelContext(container)

        // 获取当前最大 order
        let existingTasks = fetchAllTasks(conversationId: conversationId, context: context)
        let remainingCapacity = max(0, Self.maxTasksPerConversation - existingTasks.count)
        guard remainingCapacity > 0 else { return [] }

        let limitedItems = items.prefix(remainingCapacity)
        let maxOrder = existingTasks.map(\.order).max() ?? 0

        var created: [TaskItem] = []
        for (index, item) in limitedItems.enumerated() {
            let task = TaskItem(
                conversationId: conversationId,
                title: item.title,
                detail: item.detail,
                order: maxOrder + index + 1
            )
            context.insert(task)
            created.append(task)
        }

        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)追加 \(created.count) 个任务 (会话: \(conversationId))")
        }

        return created
    }

    // MARK: - Read

    /// 获取指定会话的所有任务（按 order 排序）
    public func fetchTasks(conversationId: String) -> [TaskItem] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        descriptor.fetchLimit = Self.maxTasksPerConversation

        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("\(Self.t)查询任务失败：\(error.localizedDescription)")
            return []
        }
    }

    private func fetchAllTasks(conversationId: String, context: ModelContext) -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("\(Self.t)查询全部任务失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 获取指定会话中特定状态的任务
    func fetchTasks(conversationId: String, status: TaskItem.TaskStatus) -> [TaskItem] {
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> {
                $0.conversationId == conversationId && $0.status == status
            },
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// 获取指定 ID 的任务
    func fetchTask(id: String) -> TaskItem? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    /// 获取任务进度摘要
    public func getProgressSummary(conversationId: String) -> TaskProgressSummary {
        let tasks = fetchTasks(conversationId: conversationId)

        guard !tasks.isEmpty else {
            return TaskProgressSummary(total: 0, completed: 0, inProgress: 0, pending: 0, skipped: 0)
        }

        var completed = 0, inProgress = 0, pending = 0, skipped = 0
        for task in tasks {
            switch task.status {
            case .completed: completed += 1
            case .inProgress: inProgress += 1
            case .pending: pending += 1
            case .skipped: skipped += 1
            }
        }

        return TaskProgressSummary(
            total: tasks.count,
            completed: completed,
            inProgress: inProgress,
            pending: pending,
            skipped: skipped
        )
    }

    // MARK: - Update

    /// 更新任务状态
    func updateTaskStatus(id: String, status: TaskItem.TaskStatus) throws -> Bool {
        try updateTaskStatusScoped(id: id, conversationId: nil, status: status)
    }

    /// 更新当前会话内的任务状态
    func updateTaskStatus(id: String, conversationId: String, status: TaskItem.TaskStatus) throws -> Bool {
        try updateTaskStatusScoped(id: id, conversationId: conversationId, status: status)
    }

    private func updateTaskStatusScoped(id: String, conversationId: String?, status: TaskItem.TaskStatus) throws -> Bool {
        let context = ModelContext(container)

        let descriptor: FetchDescriptor<TaskItem>
        if let conversationId {
            descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.id == id && $0.conversationId == conversationId }
            )
        } else {
            descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.id == id }
            )
        }

        guard let task = try context.fetch(descriptor).first else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)任务不存在：\(id)")
            }
            return false
        }

        task.status = status
        task.updatedAt = Date().timeIntervalSince1970
        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)任务状态更新：\(task.title) → \(status.rawValue)")
        }

        return true
    }

    /// 更新任务标题或描述
    func updateTask(id: String, title: String? = nil, detail: String? = nil) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == id }
        )

        let task: TaskItem
        do {
            guard let fetched = try context.fetch(descriptor).first else { return false }
            task = fetched
        } catch {
            Self.logger.error("\(Self.t)查询待更新任务失败：\(error.localizedDescription)")
            return false
        }

        if let title { task.title = title }
        if let detail { task.detail = detail }
        task.updatedAt = Date().timeIntervalSince1970
        guard save(context, operation: "更新任务内容") else { return false }

        return true
    }

    // MARK: - Automatic Continuation

    /// 标记某会话即将进入一次无感自动续聊轮次（在触发续聊前调用）。
    func markContinuation(conversationId: String) {
        pendingContinuationConversationIDs.insert(conversationId)
    }

    /// 若该会话当前被标记为自动续聊轮次，则消费该标记并返回 `true`。
    ///
    /// 由 `TaskContextChatMiddleware` 在每轮注入 system prompt 时调用，
    /// 一次性消费，确保只在续聊那轮生效。
    func consumeContinuation(conversationId: String) -> Bool {
        pendingContinuationConversationIDs.remove(conversationId) != nil
    }

    /// 递增并返回该会话连续自动续聊的次数。
    ///
    /// 返回 `nil` 表示已达到上限，调用方应停止自动续聊。
    func incrementContinuationCount(conversationId: String) -> Int? {
        let next = (continuationCountsByConversationID[conversationId] ?? 0) + 1
        guard next <= Self.maxAutomaticContinuations else { return nil }
        continuationCountsByConversationID[conversationId] = next
        return next
    }

    /// 将该会话的连续自动续聊计数归零。
    ///
    /// 当 LLM 在轮次中主动调用了 `update_task` 推进任务，说明它正在正常工作，
    /// 应解除"连续空转"的戒备，重新给足续聊预算。
    func resetContinuationCount(conversationId: String) {
        continuationCountsByConversationID[conversationId] = 0
    }

    // MARK: - Delete

    /// 删除指定任务
    func deleteTask(id: String) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == id }
        )

        let task: TaskItem
        do {
            guard let fetched = try context.fetch(descriptor).first else { return false }
            task = fetched
        } catch {
            Self.logger.error("\(Self.t)查询待删除任务失败：\(error.localizedDescription)")
            return false
        }

        context.delete(task)
        guard save(context, operation: "删除任务") else { return false }
        return true
    }

    /// 删除指定会话的所有任务
    @discardableResult
    func deleteAllForConversation(_ conversationId: String) -> Bool {
        let context = ModelContext(container)
        do {
            try deleteAllForConversation(conversationId, context: context)
            return true
        } catch {
            Self.logger.error("\(Self.t)删除会话任务失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    private func deleteAllForConversation(
        _ conversationId: String,
        context: ModelContext,
        saveImmediately: Bool = true
    ) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.conversationId == conversationId }
        )

        let tasks = try context.fetch(descriptor)
        for task in tasks {
            context.delete(task)
        }
        if saveImmediately {
            try context.save()
        }
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

// MARK: - Progress Summary

/// 任务进度摘要
public struct TaskProgressSummary: Sendable {
    public let total: Int
    public let completed: Int
    public let inProgress: Int
    public let pending: Int
    public let skipped: Int

    /// 完成百分比 (0-100)
    public var completionPercent: Int {
        guard total > 0 else { return 0 }
        return Int(Double(completed + skipped) / Double(total) * 100)
    }

    /// 是否所有任务都已完成或跳过
    public var isAllDone: Bool {
        total > 0 && pending == 0 && inProgress == 0
    }

    /// 是否为空（无任务）
    public var isEmpty: Bool {
        total == 0
    }
}
