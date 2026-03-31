import Foundation
import SwiftData
import MagicKit

// MARK: - TaskStoreProtocol

/// 任务存储协议
/// Store 只负责数据存储，不执行任务
protocol TaskStoreProtocol: Actor {
    /// 认领下一个待执行的任务（从 pending → running）
    func claimNextPendingTask() -> UUID?
    
    /// 获取任务详情
    func fetchTaskDetails(_ taskId: UUID) async -> (prompt: String, conversationId: UUID)?
    
    /// 更新任务状态
    func updateTask(
        id: UUID,
        status: BackgroundAgentTaskStatus,
        resultSummary: String?,
        errorDescription: String?,
        finishedAt: Date?
    )
}

// MARK: - AsyncSemaphore

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
        await withCheckedContinuation { continuation in
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

// MARK: - BackgroundAgentTaskWorker

/// Worker 负责执行任务
/// 不关心任务从哪里来，只执行
actor BackgroundAgentTaskWorker {
    private var isRunning = false
    private var workerTask: Task<Void, Never>?
    private let maxConcurrentTasks = 2
    private var runningTaskCount = 0
    private let semaphore = AsyncSemaphore(value: 2)
    
    private let store = BackgroundAgentTaskStore.shared
    private let maxToolLoopDepth = 16

    init() {
        // Worker 内部持有 Store 引用
    }

    // MARK: - Lifecycle

    nonisolated func start() {
        Task { await _start() }
    }

    nonisolated func stop() {
        Task { await _stop() }
    }

    private func _start() {
        guard !isRunning else { return }
        isRunning = true
        
        // 启动主循环
        workerTask = Task.detached { [weak self] in
            await self?.mainLoop()
        }
    }

    private func _stop() {
        isRunning = false
        workerTask?.cancel()
        workerTask = nil
    }

    // MARK: - External Triggers

    /// 外部通知有新任务创建
    nonisolated func taskDidCreate() {
        Task { [weak self] in
            await self?.fetchAndExecuteNextTask()
        }
    }

    // MARK: - Main Loop

    /// Worker 主循环：持续从 Store 获取任务并执行
    private func mainLoop() async {
        while isRunning {
            let executed = await fetchAndExecuteNextTask()
            
            if !executed {
                // 没有任务时等待
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            
            // 等待可用槽位
            await waitForAvailableSlot()
        }
    }

    private func waitForAvailableSlot() async {
        while runningTaskCount >= maxConcurrentTasks && isRunning {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    // MARK: - Task Execution

    private func fetchAndExecuteNextTask() async -> Bool {
        await semaphore.wait()
        
        guard let taskId = await store.claimNextPendingTask() else {
            semaphore.signal()
            return false
        }
        
        runningTaskCount += 1
        
        // 异步执行任务
        Task.detached { [weak self, taskId] in
            await self?.executeTask(taskId: taskId)
        }
        
        return true
    }

    private func executeTask(taskId: UUID) async {
        defer {
            runningTaskCount -= 1
            semaphore.signal()
        }
        
        do {
            // 获取任务详情
            guard let details = await store.fetchTaskDetails(taskId) else {
                throw NSError(
                    domain: "BackgroundAgentTaskWorker",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Task not found"]
                )
            }
            
            // 执行任务
            let result = try await performTaskLogic(
                taskId: details.conversationId,
                prompt: details.prompt
            )
            
            // 更新为成功状态
            await store.updateTask(
                id: taskId,
                status: .succeeded,
                resultSummary: result,
                errorDescription: nil,
                finishedAt: Date()
            )
            
        } catch {
            // 更新为失败状态
            await store.updateTask(
                id: taskId,
                status: .failed,
                resultSummary: nil,
                errorDescription: error.localizedDescription,
                finishedAt: Date()
            )
        }
    }

    // MARK: - Task Execution Logic

    private func performTaskLogic(taskId: UUID, prompt: String) async throws -> String {
        // 获取 LLM 配置（从插件的全局配置读取）
        let config = await makeCurrentLLMConfig()
        
        // 准备服务
        let llmService = LLMService()
        let toolService: ToolService = await MainActor.run {
            ToolService(llmService: llmService)
        }
        let toolExecutionService = ToolExecutionService(toolService: toolService)
        
        // 初始化消息
        var messages: [ChatMessage] = [
            ChatMessage(role: .user, conversationId: taskId, content: prompt)
        ]
        
        // 工具循环
        let finalReply = try await toolLoop(
            messages: &messages,
            llmService: llmService,
            toolService: toolService,
            toolExecutionService: toolExecutionService,
            config: config,
            taskId: taskId
        )
        
        // 检查系统错误
        if finalReply.role == .system, finalReply.isError {
            throw NSError(
                domain: "BackgroundAgentTaskWorker",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "LLM 配置无效"]
            )
        }
        
        return finalReply.content
    }

    private func toolLoop(
        messages: inout [ChatMessage],
        llmService: LLMService,
        toolService: ToolService,
            toolExecutionService: ToolExecutionService,
        config: LLMConfig,
        taskId: UUID
    ) async throws -> ChatMessage {

        for _ in 0..<maxToolLoopDepth {
            let reply = try await llmService.sendMessage(
                messages: messages,
                config: config,
                tools: toolService.tools
            )

            // 配置错误等系统消息直接返回
            if reply.role != .assistant {
                return reply
            }

            messages.append(reply)

            // 有工具调用则执行
            if let toolCalls = reply.toolCalls, !toolCalls.isEmpty {
                for call in toolCalls {
                    let result: String
                    do {
                        result = try await toolExecutionService.executeTool(call)
                    } catch {
                        // 工具执行失败，返回错误消息
                        let errorMsg = toolExecutionService.createErrorMessage(
                            for: call,
                            error: error,
                            conversationId: taskId
                        )
                        return errorMsg
                    }

                    // 添加工具结果到消息历史
                    let toolMessage = ChatMessage(
                        role: .tool,
                        conversationId: taskId,
                        content: result,
                        toolCallID: call.id
                    )
                    messages.append(toolMessage)
                }
            } else {
                // 没有工具调用，完成循环
                return reply
            }
        }

        // 达到最大深度
        return messages.last ?? ChatMessage(
            role: .system,
            conversationId: taskId,
            content: "后台任务已完成，但未获得模型回复。"
        )
    }

    // MARK: - LLM Configuration

    /// 从插件的全局配置获取 LLM 配置
    /// 配置由 BackgroundTaskConfigRootView 从 Environment 同步
    private func makeCurrentLLMConfig() async -> LLMConfig {
        // 从插件获取全局配置
        let plugin = BackgroundAgentTaskPlugin.shared
        let (providerId, model) = await plugin.getGlobalConfig()

        // 如果有全局配置，使用它
        if !providerId.isEmpty, !model.isEmpty {
            let registry = LLMProviderRegistry()
            LLMProviderRegistration.registerAllProviders(to: registry)

            guard let providerType = registry.providerType(forId: providerId) else {
                AppLogger.core.warning("🧵 未知的供应商 ID: \(providerId)，使用默认配置")
                return .default
            }

            let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

            return LLMConfig(
                apiKey: apiKey,
                model: model,
                providerId: providerId
            )
        }

        // 如果没有全局配置，回退到旧逻辑（从 LocalStore 读取）
        return await makeFallbackLLMConfig()
    }

    /// 回退配置逻辑：从 LocalStore 读取或使用默认值
    private func makeFallbackLLMConfig() async -> LLMConfig {
        let registry = LLMProviderRegistry()
        LLMProviderRegistration.registerAllProviders(to: registry)

        let globalProviderKey = "Agent_GlobalProviderId"
        let globalModelKey = "Agent_GlobalModel"

        let settingsStore = LocalStore()
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
