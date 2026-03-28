import Foundation
import SwiftData
import MagicKit

/// 后台任务存储层 - 只负责数据持久化和事件发布
actor BackgroundAgentTaskStore {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    static let shared = BackgroundAgentTaskStore()

    private let container: ModelContainer
    private let queue = DispatchQueue(label: "BackgroundAgentTaskStore.queue", qos: .utility)

    private init() {
        let schema = Schema([BackgroundAgentTask.self])

        let dbDir = AppConfig.getDBFolderURL().appendingPathComponent("BackgroundAgentTaskPlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("BackgroundAgentTask.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create BackgroundAgentTask ModelContainer: \(error)")
        }
    }

    // MARK: - 任务创建

    /// 创建新任务并发布事件
    /// - Parameter prompt: 任务指令
    /// - Returns: 任务 ID
    nonisolated func createTask(prompt: String) -> UUID {
        let id = UUID()
        let pendingStatus = BackgroundAgentTaskStatus.pending.rawValue

        queue.async { [container] in
            let context = ModelContext(container)
            let task = BackgroundAgentTask(
                id: id,
                originalPrompt: prompt,
                statusRawValue: pendingStatus
            )
            context.insert(task)
            try? context.save()
        }

        // 发布任务创建事件
        NotificationCenter.postBackgroundAgentTaskDidCreate(taskId: id)

        if Self.verbose {
            Self.logger.info("任务已创建: \(id)")
        }

        return id
    }

    // MARK: - 任务查询

    /// 获取最近的任务列表
    nonisolated func fetchRecent(limit: Int = 20) -> [BackgroundAgentTask] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 分页获取任务列表
    nonisolated func fetchPage(page: Int, pageSize: Int) -> (tasks: [BackgroundAgentTask], total: Int) {
        let context = ModelContext(container)

        let totalDescriptor = FetchDescriptor<BackgroundAgentTask>()
        let total = (try? context.fetchCount(totalDescriptor)) ?? 0

        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = max(0, (page - 1) * pageSize)
        descriptor.fetchLimit = pageSize
        let tasks = (try? context.fetch(descriptor)) ?? []

        return (tasks, total)
    }

    /// 根据 ID 查询任务
    nonisolated func fetchById(_ id: UUID) -> BackgroundAgentTask? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first) ?? nil
    }

    // MARK: - 任务删除

    /// 删除指定任务
    nonisolated func delete(_ id: UUID) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }
        context.delete(task)
        try? context.save()
    }

    /// 清空所有已完成的任务
    nonisolated func deleteCompleted() {
        let context = ModelContext(container)
        let succeededStatus = BackgroundAgentTaskStatus.succeeded.rawValue
        let failedStatus = BackgroundAgentTaskStatus.failed.rawValue
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate {
                $0.statusRawValue == succeededStatus || $0.statusRawValue == failedStatus
            }
        )
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            context.delete(task)
        }
        try? context.save()
    }

    // MARK: - Worker 接口

    /// 认领下一个待执行的任务（Worker 调用）
    /// - Returns: 任务 ID，如果没有待执行任务则返回 nil
    func claimNextPendingTask() -> UUID? {
        let context = ModelContext(container)
        let pendingStatus = BackgroundAgentTaskStatus.pending.rawValue

        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.statusRawValue == pendingStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1

        guard let task = try? context.fetch(descriptor).first else {
            return nil
        }

        // CAS 操作：更新状态为 running
        task.statusRawValue = BackgroundAgentTaskStatus.running.rawValue
        task.startedAt = Date()

        guard (try? context.save()) != nil else {
            return nil
        }

        if Self.verbose {
            Self.logger.info("任务已认领: \(task.id)")
        }

        return task.id
    }

    /// 更新任务状态（Worker 调用）
    /// - Parameters:
    ///   - id: 任务 ID
    ///   - status: 新状态
    ///   - resultSummary: 结果摘要
    ///   - errorDescription: 错误描述
    ///   - finishedAt: 完成时间
    func updateTask(
        id: UUID,
        status: BackgroundAgentTaskStatus,
        resultSummary: String?,
        errorDescription: String?,
        finishedAt: Date?
    ) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )

        guard let task = try? context.fetch(descriptor).first else { return }

        task.statusRawValue = status.rawValue
        task.resultSummary = resultSummary
        task.errorDescription = errorDescription

        if let finishedAt = finishedAt {
            task.finishedAt = finishedAt
        }

        try? context.save()

        if Self.verbose {
            Self.logger.info("任务已更新: \(id), 状态: \(status.rawValue)")
        }

        // 发布任务状态变更事件
        NotificationCenter.postBackgroundAgentTaskDidUpdate(
            taskId: id,
            status: status.rawValue
        )
    }

    /// 获取任务详情（Worker 调用）
    func fetchTaskDetails(_ id: UUID) -> (prompt: String, conversationId: UUID)? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )

        guard let task = try? context.fetch(descriptor).first else {
            return nil
        }

        return (task.originalPrompt, task.id)
    }

    // MARK: - LLM 配置

    /// 获取 LLM 配置（Worker 调用）
    func getLLMConfig() -> LLMConfig {
        let registry = LLMProviderRegistry()
        LLMProviderRegistration.registerAllProviders(to: registry)

        let settingsStore = LocalStore()

        let globalProviderKey = "Agent_GlobalProviderId"
        let globalModelKey = "Agent_GlobalModel"

        let storedProviderId = settingsStore.string(forKey: globalProviderKey)
        let storedModel = settingsStore.string(forKey: globalModelKey)

        let providerId: String
        let model: String

        if let pid = storedProviderId, !pid.isEmpty,
           let m = storedModel, !m.isEmpty {
            providerId = pid
            model = m
        } else if let first = registry.providerTypes.first {
            providerId = first.id
            model = first.defaultModel
        } else {
            return .default
        }

        guard let providerType = registry.providerType(forId: providerId) else {
            return .default
        }

        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        return LLMConfig(
            apiKey: apiKey,
            model: model,
            providerId: providerId
        )
    }
}
