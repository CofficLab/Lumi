import Foundation
import LLMKit
import os

/// 子智能体执行引擎
///
/// 管理多个并行子智能体的生命周期。每个子智能体拥有独立的
/// LLM 供应商、模型和 Agent Loop（LLM → 工具调用 → LLM → … → 结束）。
///
/// ## 设计原则
///
/// - **纯内存**：不持久化任何数据，结果返回后立即释放
/// - **并行执行**：利用 Swift Concurrency 的 TaskGroup 实现真正的并行
/// - **取消传播**：主 Agent 取消时级联取消所有子智能体
/// - **并发限制**：默认最多 5 个同时运行，防止 API 配额耗尽
actor SubAgentRunner: SuperLog {
    nonisolated static let emoji = "🤖"

    // MARK: - Singleton

    static let shared = SubAgentRunner()

    // MARK: - Properties

    /// 活跃的子智能体（agentId → context）
    private var activeAgents: [String: SubAgentContext] = [:]

    /// 最大并发数
    private let maxConcurrency = 5

    /// 最大 Agent Loop 轮次（防止无限循环）
    private let maxTurns = 20

    // MARK: - Initialization

    private init() {}

    // MARK: - Spawn

    /// 创建并启动一个子智能体
    ///
    /// - Parameters:
    ///   - task: 任务描述
    ///   - description: 简短描述（3-5 词）
    ///   - providerId: LLM 供应商 ID
    ///   - modelId: 模型 ID
    ///   - llmService: LLM 服务实例
    ///   - apiKey: API Key
    ///   - toolService: 工具服务（用于子智能体的工具调用）
    /// - Returns: agent_id
    func spawn(
        task: String,
        description: String,
        providerId: String,
        modelId: String,
        llmService: LLMService,
        apiKey: String,
        toolService: ToolService
    ) throws -> String {
        // 并发限制检查
        let runningCount = activeAgents.values.filter { $0.status == .running }.count
        guard runningCount < maxConcurrency else {
            throw SubAgentError.concurrentLimit(maxConcurrency)
        }

        let agentId = UUID().uuidString

        let context = SubAgentContext(
            agentId: agentId,
            description: description,
            providerId: providerId,
            modelId: modelId,
            task: task
        )

        activeAgents[agentId] = context

        // 启动异步执行（fire-and-forget，结果存入 context）
        context.taskHandle = Task { [weak self] in
            await self?.runAgentLoop(
                context: context,
                llmService: llmService,
                apiKey: apiKey,
                toolService: toolService
            )
        }

        MultiAgentPlugin.logger.info("\(Self.t)子智能体已创建：\(agentId.prefix(8)) (\(providerId)/\(modelId))")

        return agentId
    }

    // MARK: - Collect

    /// 等待指定的子智能体完成并返回结果
    ///
    /// - Parameters:
    ///   - agentIds: 要等待的智能体 ID 列表
    ///   - timeout: 超时秒数
    /// - Returns: 结果数组
    func collect(agentIds: [String], timeout: TimeInterval = 120) async -> [SubAgentResult] {
        let startTime = Date()

        // 持续检查直到所有指定的 agent 都完成或超时
        while Date().timeIntervalSince(startTime) < timeout {
            let allDone = agentIds.allSatisfy { id in
                if let ctx = activeAgents[id] {
                    return ctx.status != .running
                }
                return true // 不存在的视为完成
            }

            if allDone { break }

            // 短暂等待后重试
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }

        // 收集结果
        var results: [SubAgentResult] = []

        for agentId in agentIds {
            guard let ctx = activeAgents[agentId] else {
                results.append(SubAgentResult(
                    agentId: agentId,
                    status: .failed,
                    result: "Agent not found: \(agentId)",
                    providerId: "",
                    modelId: "",
                    duration: 0
                ))
                continue
            }

            if let result = ctx.result {
                results.append(result)
            } else if ctx.status == .running {
                // 超时，取消该智能体
                ctx.taskHandle?.cancel()
                ctx.status = .cancelled
                let duration = Date().timeIntervalSince(ctx.createdAt)
                let timeoutResult = SubAgentResult(
                    agentId: agentId,
                    status: .cancelled,
                    result: "Agent timed out after \(Int(timeout))s",
                    providerId: ctx.providerId,
                    modelId: ctx.modelId,
                    duration: duration
                )
                ctx.result = timeoutResult
                results.append(timeoutResult)
            }
        }

        // 清理已完成的智能体
        for agentId in agentIds {
            activeAgents.removeValue(forKey: agentId)
        }

        return results
    }

    // MARK: - Cancel All

    /// 取消所有活跃的子智能体
    func cancelAll() {
        for (_, ctx) in activeAgents {
            ctx.taskHandle?.cancel()
            if ctx.status == .running {
                ctx.status = .cancelled
            }
        }
        activeAgents.removeAll()
    }

    // MARK: - Query

    /// 获取活跃智能体数量
    func activeCount() -> Int {
        activeAgents.values.filter { $0.status == .running }.count
    }

    // MARK: - Agent Loop

    /// 执行子智能体的 Agent Loop
    ///
    /// 简化版的 Agent 循环：
    /// 1. 将 task 作为 user message 发送给指定 LLM
    /// 2. 如果返回工具调用 → 执行工具 → 将结果追加到消息 → 回到步骤 1
    /// 3. 如果返回纯文本 → 结束，返回结果
    private func runAgentLoop(
        context: SubAgentContext,
        llmService: LLMService,
        apiKey: String,
        toolService: ToolService
    ) async {
        let startTime = Date()
        let config = LLMConfig(
            apiKey: apiKey,
            model: context.modelId,
            providerId: context.providerId
        )

        // 构建初始消息列表
        var messages: [ChatMessage] = [
            ChatMessage(
                role: .user,
                conversationId: UUID(),
                content: context.task
            )
        ]

        // 准备工具列表（使用当前工具服务的只读工具子集）
        let availableTools: [SuperAgentTool]? = toolService.tools.isEmpty ? nil : toolService.tools

        var turnCount = 0

        while turnCount < maxTurns {
            turnCount += 1

            // 检查取消
            if Task.isCancelled {
                finalize(context: context, status: .cancelled, result: "Agent was cancelled", duration: Date().timeIntervalSince(startTime))
                return
            }

            // 请求 LLM（非流式，子智能体不需要流式输出）
            let response: ChatMessage
            do {
                response = try await llmService.sendMessage(
                    messages: messages,
                    config: config,
                    tools: availableTools
                )
            } catch {
                let isCancelled = Task.isCancelled
                let status: SubAgentStatus = isCancelled ? .cancelled : .failed
                let message = isCancelled ? "Agent was cancelled" : error.localizedDescription
                finalize(context: context, status: status, result: message, duration: Date().timeIntervalSince(startTime))
                return
            }

            // 追加 assistant 消息
            messages.append(response)

            // 检查是否有工具调用
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                // 执行所有工具调用
                for toolCall in toolCalls {
                    if Task.isCancelled {
                        finalize(context: context, status: .cancelled, result: "Agent was cancelled", duration: Date().timeIntervalSince(startTime))
                        return
                    }

                    let toolResult: String
                    do {
                        toolResult = try await toolService.executeTool(
                            named: toolCall.name,
                            argumentsJSON: toolCall.arguments
                        )
                    } catch {
                        toolResult = "Tool error: \(error.localizedDescription)"
                    }

                    // 追加 tool 消息
                    let toolMessage = ChatMessage(
                        role: .tool,
                        conversationId: response.conversationId,
                        content: toolResult,
                        toolCallID: toolCall.id
                    )
                    messages.append(toolMessage)
                }
                // 继续循环
            } else {
                // 无工具调用 → Agent Loop 结束
                let content = response.content
                finalize(context: context, status: .completed, result: content, duration: Date().timeIntervalSince(startTime))
                return
            }
        }

        // 超过最大轮次
        finalize(context: context, status: .failed, result: "Agent reached maximum turns (\(maxTurns))", duration: Date().timeIntervalSince(startTime))
    }

    /// 完成子智能体，设置结果
    private func finalize(
        context: SubAgentContext,
        status: SubAgentStatus,
        result: String,
        duration: TimeInterval
    ) {
        context.status = status
        context.result = SubAgentResult(
            agentId: context.agentId,
            status: status,
            result: result,
            providerId: context.providerId,
            modelId: context.modelId,
            duration: duration
        )

        MultiAgentPlugin.logger.info("\(Self.t)子智能体 \(context.agentId.prefix(8)) 完成：\(status.rawValue) (\(String(format: "%.1f", duration))s)")
    }
}

// MARK: - Errors

/// 子智能体错误
enum SubAgentError: Error, LocalizedError {
    /// 超过并发限制
    case concurrentLimit(Int)
    /// 智能体不存在
    case notFound(String)
    /// 参数缺失
    case missingArgument(String)

    var errorDescription: String? {
        switch self {
        case .concurrentLimit(let max):
            return "Maximum concurrent agents reached (\(max)). Wait for existing agents to complete."
        case .notFound(let id):
            return "Agent not found: \(id)"
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        }
    }
}
