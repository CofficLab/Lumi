import Foundation
import SwiftData
import MagicKit

/// Worker - 只负责执行任务
/// 不关心任务从哪里来，不关心任务存储，只执行
actor BackgroundAgentTaskWorker: SuperLog {
    nonisolated static let emoji = "🧵"
    nonisolated static let verbose = false

    private unowned let store: BackgroundAgentTaskStore
    private var isRunning = false
    private var workerTask: Task<Void, Never>?

    // 并发控制
    private let maxConcurrentTasks = 2
    private var runningTaskCount = 0
    private let semaphore = AsyncSemaphore(value: 2)

    // 执行配置
    private let maxToolLoopDepth = 16

    init(store: BackgroundAgentTaskStore) {
        self.store = store
    }

    // MARK: - 生命周期

    /// 启动 Worker
    nonisolated func start() {
        Task { await _start() }
    }

    /// 停止 Worker
    nonisolated func stop() {
        Task { await _stop() }
    }

    private func _start() {
        guard !isRunning else {
            if Self.verbose {
                Self.logger.info("\(self.t) Worker 已在运行中")
            }
            return
        }

        isRunning = true

        if Self.verbose {
            Self.logger.info("\(self.t) Worker 启动")
        }

        // 启动主循环
        workerTask = Task.detached { [weak self] in
            await self?.mainLoop()
        }
    }

    private func _stop() {
        isRunning = false
        workerTask?.cancel()

        if Self.verbose {
            Self.logger.info("\(self.t) Worker 停止")
        }
    }

    // MARK: - 主循环

    /// Worker 主循环：不断从 Store 获取任务并执行
    private func mainLoop() async {
        var consecutiveEmpty = 0

        while isRunning {
            // 尝试获取并执行下一个任务
            let executed = await fetchAndExecuteNextTask()

            if executed {
                consecutiveEmpty = 0
            } else {
                consecutiveEmpty += 1
            }

            // 根据空闲情况调整轮询间隔
            let pollInterval = consecutiveEmpty > 3 ? 10.0 : 2.0

            if !executed {
                if Self.verbose {
                    Self.logger.debug("\(self.t) 无任务，等待 \(pollInterval)s")
                }
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }

            // 等待可用槽位
            await waitForAvailableSlot()
        }
    }

    /// 等待并发槽位
    private func waitForAvailableSlot() async {
        while runningTaskCount >= maxConcurrentTasks && isRunning {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    // MARK: - 任务执行

    /// 获取并执行下一个任务
    /// - Returns: 是否成功获取并执行任务
    private func fetchAndExecuteNextTask() async -> Bool {
        // 等待信号量
        await semaphore.wait()

        // 从 Store 认领任务
        guard let taskId = await store.claimNextPendingTask() else {
            semaphore.signal()
            return false
        }

        runningTaskCount += 1

        if Self.verbose {
            Self.logger.info("\(self.t) 开始执行任务: \(taskId)")
        }

        // 异步执行任务
        Task.detached { [weak self, taskId] in
            await self?.executeTask(taskId: taskId)
        }

        return true
    }

    /// 执行单个任务
    private func executeTask(taskId: UUID) async {
        defer {
            runningTaskCount -= 1
            semaphore.signal()

            if Self.verbose {
                Task { [weak self] in
                    await self?.logTaskCompletion(taskId: taskId)
                }
            }
        }

        do {
            // 执行任务逻辑
            let result = try await performTaskLogic(taskId: taskId)

            // 更新为成功状态
            await store.updateTask(
                id: taskId,
                status: .succeeded,
                resultSummary: result,
                errorDescription: nil,
                finishedAt: Date()
            )

            if Self.verbose {
                Self.logger.info("\(self.t) 任务成功: \(taskId)")
            }

        } catch {
            // 更新为失败状态
            await store.updateTask(
                id: taskId,
                status: .failed,
                resultSummary: nil,
                errorDescription: error.localizedDescription,
                finishedAt: Date()
            )

            if Self.verbose {
                Self.logger.error("\(self.t) 任务失败: \(taskId), 错误: \(error.localizedDescription)")
            }
        }
    }

    /// 任务执行逻辑（纯函数式）
    private func performTaskLogic(taskId: UUID) async throws -> String {
        // 获取任务详情
        guard let details = await store.fetchTaskDetails(taskId) else {
            throw NSError(
                domain: "BackgroundAgentTaskWorker",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Task not found"]
            )
        }

        // 获取 LLM 配置
        let config = await store.getLLMConfig()

        // 准备服务
        let llmService = LLMService()
        let toolService: ToolService = await MainActor.run {
            ToolService(llmService: llmService)
        }
        let toolExecutionService = ToolExecutionService(toolService: toolService)

        // 初始化消息
        var messages: [ChatMessage] = [
            ChatMessage(role: .user, conversationId: details.conversationId, content: details.prompt)
        ]

        // 工具循环
        let finalReply = try await toolLoop(
            messages: &messages,
            llmService: llmService,
            toolExecutionService: toolExecutionService,
            config: config,
            taskId: details.conversationId
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

    /// 工具执行循环
    private func toolLoop(
        messages: inout [ChatMessage],
        llmService: LLMService,
        toolExecutionService: ToolExecutionService,
        config: LLMConfig,
        taskId: UUID
    ) async throws -> ChatMessage {

        for _ in 0..<maxToolLoopDepth {
            let reply = try await llmService.sendMessage(
                messages: messages,
                config: config,
                tools: toolExecutionService.toolService.tools
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

    // MARK: - 辅助方法

    private func logTaskCompletion(taskId: UUID) async {
        Self.logger.info("\(self.t) 任务完成: \(taskId), 当前并发数: \(runningTaskCount)")
    }
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
