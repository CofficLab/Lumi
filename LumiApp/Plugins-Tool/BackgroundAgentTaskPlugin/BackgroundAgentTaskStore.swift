import Foundation
import SwiftData
import MagicKit

/// 异步信号量，用于控制并发
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    nonisolated func signal() {
        Task {
            await _signal()
        }
    }

    private func _signal() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

actor BackgroundAgentTaskStore: SuperLog {
    nonisolated static let emoji = "🧵"
    nonisolated static let verbose = false

    nonisolated static let shared = BackgroundAgentTaskStore()

    private let container: ModelContainer
    private let queue = DispatchQueue(label: "BackgroundAgentTaskStore.queue", qos: .utility)
    private let settingsStore = BackgroundAgentTaskPluginLocalStore()

    // 并发控制：最大同时执行 2 个任务
    private let maxConcurrentTasks = 2
    private var runningTaskCount = 0
    private let taskSemaphore: AsyncSemaphore

    private init() {
        // 初始化异步信号量，最大并发数为 2
        self.taskSemaphore = AsyncSemaphore(value: maxConcurrentTasks)

        let schema = Schema([
            BackgroundAgentTask.self
        ])

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

    // MARK: - 公共方法

    /// 创建并执行新的后台任务
    /// - Parameter prompt: 任务指令
    /// - Returns: 任务 ID
    nonisolated func enqueue(prompt: String) -> UUID {
        let id = UUID()
        queue.async { [container] in
            let context = ModelContext(container)
            let task = BackgroundAgentTask(
                id: id,
                originalPrompt: prompt,
                statusRawValue: BackgroundAgentTaskStatus.pending.rawValue
            )
            context.insert(task)
            try? context.save()
        }

        Task.detached { [weak self] in
            await self?.runTask(id: id)
        }

        return id
    }

    /// 获取最近的后台任务列表
    /// - Parameter limit: 最多返回的任务数量，默认 20
    /// - Returns: 后台任务数组，按创建时间倒序
    nonisolated func fetchRecent(limit: Int = 20) -> [BackgroundAgentTask] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 分页获取后台任务列表
    /// - Parameters:
    ///   - page: 页码，从 1 开始
    ///   - pageSize: 每页数量
    /// - Returns: 分页结果（数据 + 总数）
    nonisolated func fetchPage(page: Int, pageSize: Int) -> (tasks: [BackgroundAgentTask], total: Int) {
        let context = ModelContext(container)

        // 先查总数
        let totalDescriptor = FetchDescriptor<BackgroundAgentTask>()
        let total = (try? context.fetchCount(totalDescriptor)) ?? 0

        // 再查分页数据
        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = max(0, (page - 1) * pageSize)
        descriptor.fetchLimit = pageSize
        let tasks = (try? context.fetch(descriptor)) ?? []

        return (tasks, total)
    }

    /// 根据 ID 查询后台任务
    /// - Parameter id: 任务 ID
    /// - Returns: 任务对象，不存在则返回 nil
    nonisolated func fetchById(_ id: UUID) -> BackgroundAgentTask? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first) ?? nil
    }

    /// 删除指定任务
    /// - Parameter id: 任务 ID
    nonisolated func delete(_ id: UUID) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }
        context.delete(task)
        try? context.save()
    }

    /// 清空所有已完成的任务（succeeded / failed）
    nonisolated func deleteCompleted() {
        let context = ModelContext(container)
        let succeeded = BackgroundAgentTaskStatus.succeeded.rawValue
        let failed = BackgroundAgentTaskStatus.failed.rawValue
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate {
                $0.statusRawValue == succeeded || $0.statusRawValue == failed
            }
        )
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            context.delete(task)
        }
        try? context.save()
    }

    /// 更新指定任务的状态
    /// - Parameters:
    ///   - id: 任务 ID
    ///   - mutate: 用于修改任务的闭包
    private func updateTask(
        id: UUID,
        mutate: (BackgroundAgentTask) -> Void
    ) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }
        mutate(task)
        try? context.save()
    }

    // MARK: - 任务执行

    /// 执行单个后台任务
    /// - Parameter id: 任务 ID
    private func runTask(id: UUID) async {
        // 等待获取执行许可（异步等待直到有可用位置）
        await taskSemaphore.wait()

        // 增加运行计数
        runningTaskCount += 1

        if Self.verbose {
            BackgroundAgentTaskPlugin.logger.info("\(self.t) 开始执行任务，当前并发数：\(self.runningTaskCount)")
        }

        defer {
            // 释放信号量并减少计数
            taskSemaphore.signal()
            runningTaskCount -= 1
            if Self.verbose {
                BackgroundAgentTaskPlugin.logger.info("\(self.t) 任务执行完毕，当前并发数：\(self.runningTaskCount)")
            }
        }

        // 更新任务状态为运行中
        updateTask(id: id) { task in
            task.startedAt = Date()
            task.statusRawValue = BackgroundAgentTaskStatus.running.rawValue
        }

        do {
            let config = makeCurrentLLMConfig()

            let llmService = LLMService()
            let toolService: ToolService = await MainActor.run {
                ToolService(llmService: llmService)
            }
            let toolExecutionService = ToolExecutionService(toolService: toolService)

            // 从数据库重新读取任务，确保拿到最新的 originalPrompt
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<BackgroundAgentTask>(
                predicate: #Predicate { $0.id == id }
            )
            guard let task = try context.fetch(descriptor).first else {
                throw NSError(
                    domain: "BackgroundAgentTaskStore",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Task not found"]
                )
            }

            var messages: [ChatMessage] = [
                ChatMessage(role: .user, conversationId: task.id, content: task.originalPrompt)
            ]

            let maxDepth = 16
            var finalReply: ChatMessage?

            toolLoop: for _ in 0..<maxDepth {
                let reply = try await llmService.sendMessage(
                    messages: messages,
                    config: config,
                    tools: toolService.tools
                )

                // 配置 / 供应商等问题会返回系统占位消息，不应继续工具循环或把占位键写入摘要
                if reply.role != .assistant {
                    finalReply = reply
                    break toolLoop
                }

                messages.append(reply)

                if let toolCalls = reply.toolCalls, !toolCalls.isEmpty {
                    for call in toolCalls {
                        let result: String
                        do {
                            result = try await toolExecutionService.executeTool(call)
                        } catch {
                            let errorMsg = toolExecutionService.createErrorMessage(for: call, error: error, conversationId: task.id)
                            messages.append(errorMsg)
                            finalReply = errorMsg
                            break toolLoop
                        }

                        let toolMessage = ChatMessage(
                            role: .tool,
                            conversationId: task.id,
                            content: result,
                            toolCallID: call.id
                        )
                        messages.append(toolMessage)
                    }
                    continue
                } else {
                    finalReply = reply
                    break
                }
            }

            if let final = finalReply, final.role == .system, final.isError {
                let msg = String(localized: "由于 LLM 配置无效，后台任务未能完成。")
                updateTask(id: id) { task in
                    task.finishedAt = Date()
                    task.statusRawValue = BackgroundAgentTaskStatus.failed.rawValue
                    task.resultSummary = nil
                    task.errorDescription = msg
                }
                return
            }

            let summary: String
            if let final = finalReply {
                summary = final.content
            } else {
                summary = "后台任务已完成，但未获得模型回复。"
            }

            updateTask(id: id) { task in
                task.finishedAt = Date()
                task.statusRawValue = BackgroundAgentTaskStatus.succeeded.rawValue
                task.resultSummary = summary
                task.errorDescription = nil
            }
        } catch {
            updateTask(id: id) { task in
                task.finishedAt = Date()
                task.statusRawValue = BackgroundAgentTaskStatus.failed.rawValue
                task.errorDescription = error.localizedDescription
            }
        }
    }

    // MARK: - LLM 配置

    /// 构建当前使用的 LLM 配置
    /// - Returns: LLMConfig 对象
    private func makeCurrentLLMConfig() -> LLMConfig {
        let registry = LLMProviderRegistry()
        LLMProviderRegistration.registerAllProviders(to: registry)

        // 全局配置（与 ProjectVM.GlobalConfigKeys 保持一致）
        let globalProviderKey = "Agent_GlobalProviderId"
        let globalModelKey = "Agent_GlobalModel"

        settingsStore.migrateLegacyValueIfMissing(forKey: globalProviderKey)
        settingsStore.migrateLegacyValueIfMissing(forKey: globalModelKey)
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

        settingsStore.migrateLegacyValueIfMissing(forKey: providerType.apiKeyStorageKey)
        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        return LLMConfig(
            apiKey: apiKey,
            model: model,
            providerId: providerId
        )
    }
}
