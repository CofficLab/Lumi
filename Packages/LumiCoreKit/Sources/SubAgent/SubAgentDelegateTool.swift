@preconcurrency import Foundation

// MARK: - SubAgentDelegateTool

/// 把 `LumiSubAgentDefinition` 自动包装成一个 `LumiAgentTool`，
/// 对主 LLM 完全透明（工具名 = `delegate_<definition.id>`）。
///
/// 注意：持有 `any LumiChatServicing` / `any LumiToolServicing`，
/// 无法满足严格的 `Sendable` 检查，用 `@unchecked Sendable` 抑制。
public struct SubAgentDelegateTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "delegate_subagent",
        displayName: "Delegate Sub-Agent",
        description: "Delegate a task to a registered sub-agent"
    )

    private let definition: LumiSubAgentDefinition
    private let chatService: any LumiChatServicing
    private let toolService: any LumiToolServicing

    public init(
        definition: LumiSubAgentDefinition,
        chatService: any LumiChatServicing,
        toolService: any LumiToolServicing
    ) {
        self.definition = definition
        self.chatService = chatService
        self.toolService = toolService
    }

    // MARK: - LumiAgentTool

    public var name: String { "delegate_\(definition.id)" }
    public var toolDescription: String { definition.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string("The task for the sub-agent to perform")
                ])
            ]),
            "required": .array([.string("task")])
        ])
    }

    public func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        try context.checkCancellation()

        guard let task = arguments["task"]?.stringValue, !task.isEmpty else {
            throw SubAgentError.missingArgument("task")
        }

        // 动态解析 provider（每次取最新，避免插件 reload 后实例过期）
        guard let provider = chatService.provider(forID: definition.providerID) else {
            return "Error: Provider '\(definition.providerID)' not available for sub-agent '\(definition.id)'."
        }

        // 按标签过滤工具（工具列表在 @MainActor 上下文中读取）
        let tools = resolveTools()

        let runner = SubAgentLoopRunner()
        let result = await runner.run(
            provider: provider,
            model: definition.modelID,
            systemPrompt: definition.systemPrompt,
            task: task,
            tools: tools,
            toolService: toolService,
            conversationID: context.conversationID,
            maxTurns: definition.maxTurns
        )

        return formatResult(result)
    }

    // MARK: - 工具过滤

    /// 按标签过滤工具。
    ///
    /// 过滤顺序：
    /// 1. `requiredTags == [.all]` → 返回全部工具
    /// 2. 按 `requiredTags` 过滤（OR 语义：包含任一标签即保留）
    /// 3. 移除含 `excludedTags` 任意标签的工具
    /// 4. 移除 `excludedToolNames` 中的工具
    /// 5. 补充 `additionalToolNames` 中的工具（去重）
    @MainActor
    private func resolveTools() -> [any LumiAgentTool] {
        let allTools = toolService.tools

        // 1. requiredTags 含 .all → 直接返回全部
        if definition.requiredTags.contains(.all) {
            return allTools
        }

        // 2. 按 requiredTags 过滤（OR 语义：包含任一标签即保留）
        var filtered = allTools
        if !definition.requiredTags.isEmpty {
            filtered = filtered.filter { tool in
                tool.tags.contains(where: { definition.requiredTags.contains($0) })
            }
        }

        // 3. 排除 excludedTags（包含任一排除标签即移除）
        if !definition.excludedTags.isEmpty {
            filtered = filtered.filter { tool in
                !tool.tags.contains(where: { definition.excludedTags.contains($0) })
            }
        }

        // 4. 移除 excludedToolNames
        if !definition.excludedToolNames.isEmpty {
            filtered = filtered.filter { tool in
                !definition.excludedToolNames.contains(tool.name)
            }
        }

        // 5. 加上 additionalToolNames（去重）
        if !definition.additionalToolNames.isEmpty {
            let additionalSet = Set(definition.additionalToolNames)
            let existingNames = Set(filtered.map(\.name))
            let missing = allTools.filter {
                additionalSet.contains($0.name) && !existingNames.contains($0.name)
            }
            filtered.append(contentsOf: missing)
        }

        return filtered
    }

    private func formatResult(_ result: SubAgentLoopResult) -> String {
        switch result.status {
        case .completed:
            return result.content
        case .failed:
            return "Error: \(result.error ?? "Unknown error")"
        case .maxTurnsReached:
            return "Max turns reached. Result: \(result.content)"
        }
    }
}

// MARK: - SubAgentError

public enum SubAgentError: Error, Sendable {
    case missingArgument(String)
}

// MARK: - SubAgentLoopResult

public struct SubAgentLoopResult: Sendable {
    public enum Status: Sendable {
        /// 子 Agent 产出最终文本（无更多工具调用）
        case completed
        /// LLM 调用出错
        case failed
        /// 达到最大轮数
        case maxTurnsReached
    }

    public let content: String
    public let status: Status
    public let duration: Double
    public let error: String?

    public init(
        content: String,
        status: Status,
        duration: Double,
        error: String? = nil
    ) {
        self.content = content
        self.status = status
        self.duration = duration
        self.error = error
    }
}

// MARK: - SubAgentLoopRunner

/// 自包含的 agent loop 引擎，不依赖 ChatService 会话状态。
///
/// 参照 `ChatService.runAgentTurn` 的三阶段结构（LLM 调用 → turn check → 工具执行），
/// 剥离所有 UI / 持久化 / 审批耦合，维护自己的局部 `[LumiChatMessage]` 数组。
public struct SubAgentLoopRunner {
    public init() {}

    /// 执行隔离的子 Agent 推理循环。
    ///
    /// - Parameters:
    ///   - provider: 子 Agent 绑定的 LLM provider 实例
    ///   - model: 模型 id
    ///   - systemPrompt: 子 Agent 的系统提示
    ///   - task: 主 Agent 传入的任务描述
    ///   - tools: 已按标签过滤的工具子集
    ///   - toolService: 工具执行服务（复用主会话的，继承路径白名单/取消机制）
    ///   - conversationID: 复用主会话 ID（工具执行时传入）
    ///   - maxTurns: 最大推理轮数
    /// - Returns: 子 Agent 的最终文本结论
    @MainActor public func run(
        provider: any LumiLLMProvider,
        model: String,
        systemPrompt: String,
        task: String,
        tools: [any LumiAgentTool],
        toolService: any LumiToolServicing,
        conversationID: UUID,
        maxTurns: Int = 10
    ) async -> SubAgentLoopResult {
        let start = Date()
        var messages: [LumiChatMessage] = [
            LumiChatMessage(conversationID: conversationID, role: .system, content: systemPrompt),
            LumiChatMessage(conversationID: conversationID, role: .user, content: task)
        ]

        for _ in 0..<maxTurns {
            try? Task.checkCancellation()

            // Phase 1: 调 LLM（子 Agent 无 UI，onChunk 丢弃）
            let request = LumiLLMRequest(messages: messages, model: model, tools: tools)
            var assistant: LumiChatMessage
            do {
                assistant = try await provider.sendStreaming(request) { _ in }
            } catch {
                return SubAgentLoopResult(
                    content: error.localizedDescription,
                    status: .failed,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription
                )
            }

            // 子 Agent 同样检测正文内联工具调用，重试 1 次。
            // 将首次（错误）回复与纠正 nudge 临时拼进请求列表，不写入主上下文。
            if assistant.hasInlineToolCallInBody {
                let nudge = LumiChatMessage(
                    conversationID: conversationID,
                    role: .system,
                    content: "Note: Your previous response wrote tool calls as text in the body " +
                        "instead of using the structured tool-call interface. That is incorrect. " +
                        "Please regenerate your response and invoke tools via the tool_use interface; " +
                        "do not emit <tool_call>, <function_calls>, JSON tool-call blocks, etc. in the body.",
                    metadata: ["lumi-nudge": "inline-tool-call-retry"]
                )
                let retriedRequest = LumiLLMRequest(
                    messages: messages + [assistant, nudge],
                    model: model,
                    tools: tools
                )
                do {
                    assistant = try await provider.sendStreaming(retriedRequest) { _ in }
                } catch {
                    // 重试本身失败 → 用原 assistant 继续（后续按无工具调用收尾）
                }
            }

            messages.append(assistant)

            // Phase 2: 无工具调用 → 收尾，返回最终文本
            guard let toolCalls = assistant.toolCalls, !toolCalls.isEmpty else {
                return SubAgentLoopResult(
                    content: assistant.content,
                    status: .completed,
                    duration: Date().timeIntervalSince(start)
                )
            }

            // Phase 3: 逐个执行工具，结果回环到局部 messages（不写主上下文）
            for toolCall in toolCalls {
                try? Task.checkCancellation()
                let result = await toolService.execute(toolCall, conversationID: conversationID)
                messages.append(LumiChatMessage(
                    conversationID: conversationID,
                    role: .tool,
                    content: result.content,
                    toolCallID: toolCall.id
                ))
            }
        }

        let lastAssistant = messages.last(where: { $0.role == .assistant })
        return SubAgentLoopResult(
            content: lastAssistant?.content ?? "",
            status: .maxTurnsReached,
            duration: Date().timeIntervalSince(start)
        )
    }
}
