import Foundation
import SwiftData
import MagicKit

actor BackgroundAgentTaskStore: TaskStoreProtocol {
    nonisolated static let shared = BackgroundAgentTaskStore()

    // nonisolated(unsafe): 让 nonisolated 方法可在调用方的执行上下文直接访问 container，
    // 无需跳入 actor 队列（actor 默认 QoS 为 User-Interactive），从而消除优先级反转。
    // ModelContainer 本身是线程安全的，此处使用是安全的。
    private nonisolated(unsafe) let container: ModelContainer

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

    // MARK: - Private I/O Helper

    /// 在 .utility QoS 下执行 SwiftData I/O 操作。
    /// SwiftData 的 ModelContext.fetch/save 内部 SQLite I/O 运行在 Background QoS 线程，
    /// 如果调用方在 User-Interactive（主线程）上同步等待，会产生优先级反转。
    /// 使用 DispatchQueue.global(qos: .utility) 将 I/O 调度到 .utility QoS 线程，
    /// 消除主线程（User-Interactive）同步等待 Background QoS 的优先级反转警告。
    private nonisolated func performIO<T>(_ block: @escaping (ModelContainer) -> T) async -> T {
        let capturedContainer = container
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = block(capturedContainer)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Public Methods - Task Management

    /// 创建新的后台任务（并存入数据库）
    nonisolated func enqueue(prompt: String) async -> UUID {
        let id = UUID()
        let pendingStatus = BackgroundAgentTaskStatus.pending.rawValue

        await performIO { container in
            let context = ModelContext(container)
            let task = BackgroundAgentTask(
                id: id,
                originalPrompt: prompt,
                statusRawValue: pendingStatus
            )
            context.insert(task)
            try? context.save()
        }

        // 发出通知（Store 的唯一职责之一）
        NotificationCenter.postBackgroundAgentTaskDidCreate(taskId: id)

        return id
    }

    /// 获取最近的后台任务列表
    nonisolated func fetchRecent(limit: Int = 20) async -> [BackgroundAgentTask] {
        await performIO { container in
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<BackgroundAgentTask>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            return (try? context.fetch(descriptor)) ?? []
        }
    }

    /// 分页获取后台任务列表
    nonisolated func fetchPage(page: Int, pageSize: Int) async -> (tasks: [BackgroundAgentTask], total: Int) {
        await performIO { container in
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
    }

    /// 根据 ID 查询后台任务
    nonisolated func fetchById(_ id: UUID) async -> BackgroundAgentTask? {
        await performIO { container in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<BackgroundAgentTask>(
                predicate: #Predicate { $0.id == id }
            )
            return (try? context.fetch(descriptor).first) ?? nil
        }
    }

    /// 删除指定任务
    nonisolated func delete(_ id: UUID) async {
        await performIO { container in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<BackgroundAgentTask>(
                predicate: #Predicate { $0.id == id }
            )
            guard let task = try? context.fetch(descriptor).first else { return }
            context.delete(task)
            try? context.save()
        }
    }

    /// 清空所有已完成的任务（succeeded / failed）
    nonisolated func deleteCompleted() async {
        await performIO { container in
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
    }

    // MARK: - Protocol Implementation - Worker Interface

    /// 认领下一个待执行的任务（从 pending → running）
    nonisolated func claimNextPendingTask() async -> UUID? {
        await performIO { container in
            let context = ModelContext(container)
            let pendingStatus = BackgroundAgentTaskStatus.pending.rawValue
            let runningStatus = BackgroundAgentTaskStatus.running.rawValue
            
            var descriptor = FetchDescriptor<BackgroundAgentTask>(
                predicate: #Predicate {
                    $0.statusRawValue == pendingStatus
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = 1
            
            guard let task = try? context.fetch(descriptor).first else {
                return nil
            }
            
            task.statusRawValue = runningStatus
            task.startedAt = Date()
            
            guard (try? context.save()) != nil else {
                return nil
            }
            
            return task.id
        }
    }

    /// 获取任务详情（Worker 调用）
    nonisolated func fetchTaskDetails(_ taskId: UUID) async -> (prompt: String, conversationId: UUID)? {
        await performIO { container in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<BackgroundAgentTask>(
                predicate: #Predicate { $0.id == taskId }
            )
            
            guard let task = try? context.fetch(descriptor).first else {
                return nil
            }
            
            return (task.originalPrompt, task.id)
        }
    }

    /// 更新任务状态（Worker 调用）
    nonisolated func updateTask(
        id: UUID,
        status: BackgroundAgentTaskStatus,
        resultSummary: String?,
        errorDescription: String?,
        finishedAt: Date?
    ) async {
        await performIO { container in
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
            
            // 发出更新通知
            NotificationCenter.postBackgroundAgentTaskDidUpdate(
                taskId: id,
                status: status.rawValue
            )
        }
    }
}
