import Foundation
import MagicKit
import SwiftData
import os

/// AutoTask 插件的状态管理器
///
/// 通过 SwiftData 管理任务的增删改查。
/// 使用 Actor 模式确保线程安全，参考 `CacheManager` 模板。
actor TaskStateManager: SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false

    // MARK: - Singleton

    static let shared = TaskStateManager()

    // MARK: - Properties

    private let container: ModelContainer

    /// 单个会话最大任务数
    private let maxTasksPerConversation = 50

    // MARK: - Initialization

    private init() {
        let schema = Schema([TaskItem.self])

        let dbDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("AutoTaskPlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("tasks.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create AutoTaskPlugin ModelContainer: \(error)")
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
    ) -> TaskItem {
        let context = ModelContext(container)
        let task = TaskItem(
            conversationId: conversationId,
            title: title,
            detail: detail,
            order: order
        )
        context.insert(task)
        try? context.save()

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)创建任务：[\(order)] \(title)")
        }

        return task
    }

    /// 批量创建任务（用于一次性拆解后批量写入）
    func createTasks(conversationId: String, items: [(title: String, detail: String?)]) {
        let context = ModelContext(container)

        // 先清除该会话的所有旧任务
        deleteAllForConversation(conversationId, context: context)

        for (index, item) in items.enumerated() {
            let task = TaskItem(
                conversationId: conversationId,
                title: item.title,
                detail: item.detail,
                order: index + 1
            )
            context.insert(task)
        }

        try? context.save()

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)批量创建 \(items.count) 个任务 (会话: \(conversationId))")
        }
    }

    // MARK: - Read

    /// 获取指定会话的所有任务（按 order 排序）
    func fetchTasks(conversationId: String) -> [TaskItem] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        descriptor.fetchLimit = maxTasksPerConversation

        do {
            return try context.fetch(descriptor)
        } catch {
            AutoTaskPlugin.logger.error("\(Self.t)查询任务失败：\(error.localizedDescription)")
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
    func getProgressSummary(conversationId: String) -> TaskProgressSummary {
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
    func updateTaskStatus(id: String, status: TaskItem.TaskStatus) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == id }
        )

        guard let task = try? context.fetch(descriptor).first else {
            if Self.verbose {
                AutoTaskPlugin.logger.warning("\(Self.t)任务不存在：\(id)")
            }
            return false
        }

        task.status = status
        task.updatedAt = Date().timeIntervalSince1970
        try? context.save()

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)任务状态更新：\(task.title) → \(status.rawValue)")
        }

        return true
    }

    /// 更新任务标题或描述
    func updateTask(id: String, title: String? = nil, detail: String? = nil) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == id }
        )

        guard let task = try? context.fetch(descriptor).first else { return false }

        if let title { task.title = title }
        if let detail { task.detail = detail }
        task.updatedAt = Date().timeIntervalSince1970
        try? context.save()

        return true
    }

    // MARK: - Delete

    /// 删除指定任务
    func deleteTask(id: String) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == id }
        )

        guard let task = try? context.fetch(descriptor).first else { return false }
        context.delete(task)
        try? context.save()
        return true
    }

    /// 删除指定会话的所有任务
    func deleteAllForConversation(_ conversationId: String) {
        let context = ModelContext(container)
        deleteAllForConversation(conversationId, context: context)
    }

    // MARK: - Private

    private func deleteAllForConversation(_ conversationId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.conversationId == conversationId }
        )

        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            context.delete(task)
        }
        try? context.save()
    }
}

// MARK: - Progress Summary

/// 任务进度摘要
struct TaskProgressSummary: Sendable {
    let total: Int
    let completed: Int
    let inProgress: Int
    let pending: Int
    let skipped: Int

    /// 完成百分比 (0-100)
    var completionPercent: Int {
        guard total > 0 else { return 0 }
        return Int(Double(completed + skipped) / Double(total) * 100)
    }

    /// 是否所有任务都已完成或跳过
    var isAllDone: Bool {
        total > 0 && pending == 0 && inProgress == 0
    }

    /// 是否为空（无任务）
    var isEmpty: Bool {
        total == 0
    }
}
