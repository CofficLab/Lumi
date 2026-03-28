import Foundation
import SwiftData
import MagicKit

actor BackgroundAgentTaskStore: TaskStoreProtocol {
    nonisolated static let shared = BackgroundAgentTaskStore()
    
    private nonisolated(unsafe) static var workerStarted = false
    private static let startQueue = DispatchQueue(label: "com.coffic.lumi.backgroundtask.start")

    private let container: ModelContainer
    private let queue = DispatchQueue(label: "BackgroundAgentTaskStore.queue", qos: .utility)
    private let settingsStore = LocalStore()
    private var worker: BackgroundAgentTaskWorker?

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
        
        self.worker = nil
    }
    
    private nonisolated func ensureWorkerStarted() {
        Self.startQueue.sync {
            guard !Self.workerStarted else { return }
            Self.workerStarted = true
            
            Task { [weak self] in
                guard let self = self else { return }
                let newWorker = BackgroundAgentTaskWorker(store: self)
                await self.setWorker(newWorker)
                await newWorker.start()
            }
        }
    }
    
    private func setWorker(_ worker: BackgroundAgentTaskWorker) {
        self.worker = worker
    }

    // MARK: - Public Methods

    nonisolated func enqueue(prompt: String) -> UUID {
        ensureWorkerStarted()
        
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
        
        NotificationCenter.postBackgroundAgentTaskDidCreate(taskId: id)
        
        return id
    }

    nonisolated func fetchRecent(limit: Int = 20) -> [BackgroundAgentTask] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

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

    nonisolated func fetchById(_ id: UUID) -> BackgroundAgentTask? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first) ?? nil
    }

    nonisolated func delete(_ id: UUID) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }
        context.delete(task)
        try? context.save()
    }

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

    // MARK: - Protocol Implementation

    func claimNextPendingTask() -> UUID? {
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
    }

    func performTask(taskId: UUID) async throws -> (summary: String, error: Error?) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == taskId }
        )
        
        guard let task = try context.fetch(descriptor).first else {
            throw NSError(
                domain: "BackgroundAgentTaskStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Task not found"]
            )
        }
        
        let config = makeCurrentLLMConfig()
        
        let llmService = LLMService()
        let toolService: ToolService = await MainActor.run {
            ToolService(llmService: llmService)
        }
        let toolExecutionService = ToolExecutionService(toolService: toolService)
        
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
            throw NSError(
                domain: "BackgroundAgentTaskStore",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "LLM 配置无效"]
            )
        }
        
        let summary: String
        if let final = finalReply {
            summary = final.content
        } else {
            summary = "后台任务已完成，但未获得模型回复。"
        }
        
        return (summary, nil)
    }

    // MARK: - LLM Configuration

    private func makeCurrentLLMConfig() -> LLMConfig {
        let registry = LLMProviderRegistry()
        LLMProviderRegistration.registerAllProviders(to: registry)
        
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
