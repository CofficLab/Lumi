import Foundation
import SwiftData
import SuperLogKit
import os

/// GoalTask 插件的状态管理器
///
/// 通过 SwiftData 管理 Goal 和 Task 的增删改查。
/// 使用 Actor 模式确保线程安全。
///
/// 生命周期由 `GoalTaskPlugin` 在 `lifecycle(.didRegister)` 中初始化。
public actor GoalStateManager: SuperLog {
    nonisolated public static let emoji = "🎯"
    nonisolated public static let verbose: Bool = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "goaltask.state-manager")
    
    // MARK: - Properties
    
    private let container: ModelContainer
    
    /// 单个会话最大 Goal 数
    nonisolated static let maxGoalsPerConversation = 10
    
    /// 单个 Goal 最大 Task 数
    nonisolated static let maxTasksPerGoal = 50
    
    // MARK: - Initialization
    
    public init(databaseRootURL: URL) {
        self.container = Self.makeContainer(databaseRootURL: databaseRootURL)
    }
    
    static func makeContainer(databaseRootURL: URL) -> ModelContainer {
        let schema = Schema([Goal.self, GoalTask.self])
        let dbDir = databaseRootURL.appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("goals.sqlite")
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
            preconditionFailure("Could not create in-memory GoalTaskPlugin ModelContainer: \(error)")
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
    
    /// 创建 Goal 及其关联的 Tasks
    @discardableResult
    func createGoal(
        conversationId: String,
        title: String,
        description: String?,
        successCriteria: String?,
        tasks: [(title: String, description: String?, executionContext: String?, parallelGroup: String?)]
    ) throws -> (goal: Goal, tasks: [GoalTask]) {
        let context = ModelContext(container)
        
        // 检查会话的 Goal 数量限制
        let existingGoals = fetchAllGoals(conversationId: conversationId, context: context)
        guard existingGoals.count < Self.maxGoalsPerConversation else {
            throw GoalStateError.tooManyGoals(max: Self.maxGoalsPerConversation)
        }
        
        // 创建 Goal
        let goal = Goal(
            conversationId: conversationId,
            title: title,
            goalDescription: description,
            successCriteria: successCriteria
        )
        context.insert(goal)
        
        // 创建关联的 Tasks
        let limitedTasks = Array(tasks.prefix(Self.maxTasksPerGoal))
        var createdTasks: [GoalTask] = []
        
        for (index, taskInfo) in limitedTasks.enumerated() {
            let task = GoalTask(
                goalId: goal.id,
                title: taskInfo.title,
                taskDescription: taskInfo.description,
                executionContext: taskInfo.executionContext,
                order: index + 1,
                parallelGroup: taskInfo.parallelGroup
            )
            // 第一个任务标记为 in_progress
            if index == 0 {
                task.status = .inProgress
                task.updatedAt = Date().timeIntervalSince1970
                goal.status = .inProgress
            }
            context.insert(task)
            createdTasks.append(task)
        }
        
        try context.save()
        
        if Self.verbose {
            Self.logger.info("\(Self.t)创建 Goal: \(title), 包含 \(createdTasks.count) 个 Task")
        }
        
        return (goal, createdTasks)
    }
    
    /// 向已有 Goal 追加新 Tasks
    @discardableResult
    func addTasksToGoal(
        goalId: String,
        tasks: [(title: String, description: String?, executionContext: String?, parallelGroup: String?)]
    ) throws -> [GoalTask] {
        let context = ModelContext(container)
        
        guard let goal = fetchGoal(id: goalId, context: context) else {
            throw GoalStateError.goalNotFound(id: goalId)
        }
        
        // 获取当前最大 order
        let existingTasks = fetchAllTasks(goalId: goalId, context: context)
        let remainingCapacity = max(0, Self.maxTasksPerGoal - existingTasks.count)
        guard remainingCapacity > 0 else {
            throw GoalStateError.tooManyTasks(max: Self.maxTasksPerGoal)
        }
        
        let limitedTasks = Array(tasks.prefix(remainingCapacity))
        let maxOrder = existingTasks.map(\.order).max() ?? 0
        
        var createdTasks: [GoalTask] = []
        for (index, taskInfo) in limitedTasks.enumerated() {
            let task = GoalTask(
                goalId: goalId,
                title: taskInfo.title,
                taskDescription: taskInfo.description,
                executionContext: taskInfo.executionContext,
                order: maxOrder + index + 1,
                parallelGroup: taskInfo.parallelGroup
            )
            context.insert(task)
            createdTasks.append(task)
        }
        
        goal.updatedAt = Date().timeIntervalSince1970
        try context.save()
        
        if Self.verbose {
            Self.logger.info("\(Self.t)向 Goal \(goalId) 追加 \(createdTasks.count) 个 Task")
        }
        
        return createdTasks
    }
    
    // MARK: - Read
    
    /// 获取指定会话的所有 Goals
    func fetchGoals(conversationId: String) -> [Goal] {
        let context = ModelContext(container)
        return fetchAllGoals(conversationId: conversationId, context: context)
    }
    
    private func fetchAllGoals(conversationId: String, context: ModelContext) -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("\(Self.t)查询 Goals 失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取指定 ID 的 Goal
    func fetchGoal(id: String) -> Goal? {
        let context = ModelContext(container)
        return fetchGoal(id: id, context: context)
    }
    
    private func fetchGoal(id: String, context: ModelContext) -> Goal? {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    /// 获取指定 Goal 的所有 Tasks
    func fetchTasks(goalId: String) -> [GoalTask] {
        let context = ModelContext(container)
        return fetchAllTasks(goalId: goalId, context: context)
    }
    
    private func fetchAllTasks(goalId: String, context: ModelContext) -> [GoalTask] {
        let descriptor = FetchDescriptor<GoalTask>(
            predicate: #Predicate<GoalTask> { $0.goalId == goalId },
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("\(Self.t)查询 Tasks 失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取指定 ID 的 GoalTask
    func fetchGoalTask(id: String) -> GoalTask? {
        let context = ModelContext(container)
        return fetchGoalTask(id: id, context: context)
    }
    
    private func fetchGoalTask(id: String, context: ModelContext) -> GoalTask? {
        let descriptor = FetchDescriptor<GoalTask>(
            predicate: #Predicate<GoalTask> { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Update
    
    /// 更新 GoalTask 状态
    func updateGoalTaskStatus(
        id: String,
        status: GoalTask.TaskStatus,
        result: String? = nil,
        errorMessage: String? = nil
    ) throws -> (task: GoalTask, goal: Goal) {
        let context = ModelContext(container)
        
        guard let task = fetchGoalTask(id: id, context: context) else {
            throw GoalStateError.taskNotFound(id: id)
        }
        
        guard let goal = fetchGoal(id: task.goalId, context: context) else {
            throw GoalStateError.goalNotFound(id: task.goalId)
        }
        
        task.status = status
        task.updatedAt = Date().timeIntervalSince1970
        
        if status == .completed {
            task.completedAt = Date().timeIntervalSince1970
            if let result {
                task.result = result
            }
        }
        
        if status == .failed {
            if let errorMessage {
                task.errorMessage = errorMessage
            }
        }
        
        // 自动推导 Goal 状态
        let derivedStatus = deriveGoalStatus(goalId: goal.id, context: context)
        // 只有当 LLM 没有手动设置 blocked/failed 时才自动推导
        let blocked: Goal.GoalStatus = .blocked
        let failed: Goal.GoalStatus = .failed
        if goal.status != blocked && goal.status != failed {
            goal.status = derivedStatus
            goal.updatedAt = Date().timeIntervalSince1970
            
            if derivedStatus == .completed {
                goal.completedAt = Date().timeIntervalSince1970
            }
        }
        
        try context.save()
        
        if Self.verbose {
            Self.logger.info("\(Self.t)更新 Task \(id) 状态为 \(status.rawValue)，Goal 状态推导为 \(goal.status.rawValue)")
        }
        
        return (task, goal)
    }
    
    /// 更新 Goal 状态（LLM 手动覆盖）
    func updateGoalStatus(
        id: String,
        status: Goal.GoalStatus,
        blockedReason: String? = nil,
        failureReason: String? = nil
    ) throws -> Goal {
        let context = ModelContext(container)
        
        guard let goal = fetchGoal(id: id, context: context) else {
            throw GoalStateError.goalNotFound(id: id)
        }
        
        goal.status = status
        goal.updatedAt = Date().timeIntervalSince1970
        
        if status == .blocked {
            goal.blockedReason = blockedReason
        }
        
        if status == .failed {
            goal.failureReason = failureReason
        }
        
        if status == .completed {
            goal.completedAt = Date().timeIntervalSince1970
        }
        
        try context.save()
        
        if Self.verbose {
            Self.logger.info("\(Self.t)手动更新 Goal \(id) 状态为 \(status.rawValue)")
        }
        
        return goal
    }
    
    /// 根据 Tasks 状态推导 Goal 状态
    private func deriveGoalStatus(goalId: String, context: ModelContext) -> Goal.GoalStatus {
        let tasks = fetchAllTasks(goalId: goalId, context: context)
        
        guard !tasks.isEmpty else {
            return .pending
        }
        
        let completed = tasks.filter { $0.status == .completed }.count
        let failed = tasks.filter { $0.status == .failed }.count
        let skipped = tasks.filter { $0.status == .skipped }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        let total = tasks.count
        
        // 全部完成或跳过（允许部分跳过）
        if completed + skipped == total {
            return .completed
        }
        
        // 全部失败
        if failed == total {
            return .failed
        }
        
        // 有任务正在进行或已完成
        if inProgress > 0 || completed > 0 {
            return .inProgress
        }
        
        return .pending
    }
    
    // MARK: - Delete
    
    /// 删除指定会话的所有 Goals
    func deleteAllGoals(conversationId: String) throws {
        let context = ModelContext(container)
        let goals = fetchAllGoals(conversationId: conversationId, context: context)
        
        for goal in goals {
            context.delete(goal)
        }
        
        try context.save()
        
        if Self.verbose {
            Self.logger.info("\(Self.t)删除会话 \(conversationId) 的所有 Goals")
        }
    }
}

// MARK: - Errors

/// GoalStateManager 错误类型
public enum GoalStateError: LocalizedError {
    case tooManyGoals(max: Int)
    case tooManyTasks(max: Int)
    case goalNotFound(id: String)
    case taskNotFound(id: String)
    
    public var errorDescription: String? {
        switch self {
        case .tooManyGoals(let max):
            return "Too many goals (max: \(max))"
        case .tooManyTasks(let max):
            return "Too many tasks (max: \(max))"
        case .goalNotFound(let id):
            return "Goal not found: \(id)"
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        }
    }
}

// MARK: - Summary

/// Goal 进度摘要
public struct GoalProgressSummary: Sendable {
    public let goalId: String
    public let goalTitle: String
    public let goalStatus: Goal.GoalStatus
    public let totalTasks: Int
    public let completedTasks: Int
    public let inProgressTasks: Int
    public let pendingTasks: Int
    public let failedTasks: Int
    public let skippedTasks: Int
    
    /// 完成百分比 (0-100)
    public var completionPercent: Int {
        guard totalTasks > 0 else { return 0 }
        return Int(Double(completedTasks + skippedTasks) / Double(totalTasks) * 100)
    }
    
    /// 是否所有任务都已完成或跳过
    public var isAllDone: Bool {
        totalTasks > 0 && pendingTasks == 0 && inProgressTasks == 0
    }
}