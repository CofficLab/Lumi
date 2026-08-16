import Foundation
import ProviderMessage

/// Provider-facing request. Protocol details (OpenAI, Anthropic, local models)
/// stay outside KernelCore and are translated by each concrete provider.
public struct LLMRequest: Sendable {
    public let conversationID: UUID
    public let messages: [Message]
    public let model: String?
    /// 本轮可调用的工具（由 AgentLoop 从 `SuperAgentTool` 转换而来）。
    /// 为空 / nil 表示不附加任何工具。
    public let tools: [LLMFunctionSchema]?
    /// 推理档位（"low"/"medium"/"high"/"xhigh"/"max"），供应商按能力映射；
    /// nil 表示不显式要求思考（由供应商默认行为决定）。
    public let reasoningEffort: String?

    public init(
        conversationID: UUID,
        messages: [Message],
        model: String? = nil,
        tools: [LLMFunctionSchema]? = nil,
        reasoningEffort: String? = nil
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.model = model
        self.tools = tools
        self.reasoningEffort = reasoningEffort
    }
}

public struct LLMResponse: Sendable, Equatable {
    public let content: String
    public let model: String?
    /// 模型请求执行的工具调用（流式与非流式路径都可能返回）。
    public let toolCalls: [MessageToolCall]?
    /// 思考/推理内容（reasoning）。
    public let reasoningContent: String?
    public let inputTokenCount: Int?
    public let outputTokenCount: Int?
    public let cachedInputTokenCount: Int?
    /// 供应商返回的结束原因（如 "stop" / "tool_calls"）。
    public let stopReason: String?

    public init(
        content: String,
        model: String? = nil,
        toolCalls: [MessageToolCall]? = nil,
        reasoningContent: String? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        cachedInputTokenCount: Int? = nil,
        stopReason: String? = nil
    ) {
        self.content = content
        self.model = model
        self.toolCalls = toolCalls
        self.reasoningContent = reasoningContent
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.cachedInputTokenCount = cachedInputTokenCount
        self.stopReason = stopReason
    }
}

/// 一次流式增量。供应商把 SSE 流解析为多个 chunk 逐次回调；
/// 文本增量与思考增量可能交错出现，由 AgentLoop 决定写入流式行还是思考区。
public struct LLMStreamChunk: Sendable {
    public let content: String?
    /// true 表示该增量属于思考/推理内容。
    public let isThinking: Bool
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cachedInputTokens: Int?
    public let stopReason: String?
    /// 流结束信号（[DONE]）。
    public let isDone: Bool

    public init(
        content: String? = nil,
        isThinking: Bool = false,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        stopReason: String? = nil,
        isDone: Bool = false
    ) {
        self.content = content
        self.isThinking = isThinking
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.stopReason = stopReason
        self.isDone = isDone
    }
}

/// 发送给 LLM 的工具函数 schema（JSON Schema 风格）。
///
/// 定义在 ProviderLLM 而非 ProviderLLMVendors，避免依赖方向倒挂：
/// AgentLoop / MessageSender 等上层只依赖本类型；具体供应商把
/// `LLMFunctionSchema` 转换为自己的协议格式（OpenAI `tools` 数组、
/// Anthropic `tools` 数组等）。
///
/// `parameters` 是 JSON Schema 字典（`[String: Any]`，非 Sendable），
/// 因此整个类型标记为 `@unchecked Sendable`，与上游 `inputSchema` 语义一致。
public struct LLMFunctionSchema: @unchecked Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: [String: Any]

    public init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    public static func == (lhs: LLMFunctionSchema, rhs: LLMFunctionSchema) -> Bool {
        lhs.name == rhs.name
            && lhs.description == rhs.description
            && NSDictionary(dictionary: lhs.parameters).isEqual(to: rhs.parameters)
    }
}

public enum LLMProviderError: Error, LocalizedError, Sendable, Equatable {
    case notConfigured
    case emptyResponse
    case providerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "LLM provider is not configured"
        case .emptyResponse: return "LLM provider returned an empty response"
        case .providerUnavailable(let reason): return "LLM provider unavailable: \(reason)"
        }
    }
}

/// Minimal model boundary consumed by AgentLoop. Concrete network/auth/protocol
/// implementations belong in Provider packages or plugins.
public protocol LLMProviding: AnyObject, Sendable {
    var providerID: String { get }
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

/// 可选流式能力：供应商实现该协议后，AgentLoop 优先使用流式路径；
/// 未实现时 AgentLoop 回退到 `complete(_:)` 非流式（体验降级但功能可用）。
public protocol LLMStreamingProviding: LLMProviding {
    /// 流式完成一次请求。`onChunk` 在后台任务中按到达顺序调用（Sendable），
    /// 实现方应把 `await` 用于跳回 MainActor 的写操作（如 MessageStreaming）。
    ///
    /// - Returns: 完整响应（含最终正文、工具调用与用量统计）；流式增量只是
    ///   中间过程，返回的 `LLMResponse` 才是落库依据。
    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse
}
