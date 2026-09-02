import Foundation
import ProviderMessage

public enum LLMContextPreparationMode: String, Sendable {
    case prewarm
    case beforeSend
    case emergency
}

/// 一次 LLM 请求可用于输入上下文的 token 预算。
public struct LLMContextBudget: Sendable, Equatable {
    public let contextWindowTokens: Int?
    public let reservedOutputTokens: Int
    public let toolSchemaTokens: Int
    public let safetyMarginTokens: Int
    public let fallbackContextWindowTokens: Int

    public init(
        contextWindowTokens: Int?,
        reservedOutputTokens: Int = 8_000,
        toolSchemaTokens: Int = 0,
        safetyMarginTokens: Int = 2_000,
        fallbackContextWindowTokens: Int = 32_000
    ) {
        self.contextWindowTokens = contextWindowTokens
        self.reservedOutputTokens = max(reservedOutputTokens, 0)
        self.toolSchemaTokens = max(toolSchemaTokens, 0)
        self.safetyMarginTokens = max(safetyMarginTokens, 0)
        self.fallbackContextWindowTokens = max(fallbackContextWindowTokens, 4_096)
    }

    public var effectiveContextWindowTokens: Int {
        max(contextWindowTokens ?? fallbackContextWindowTokens, 4_096)
    }

    public var inputTokenLimit: Int {
        max(
            effectiveContextWindowTokens
                - reservedOutputTokens
                - toolSchemaTokens
                - safetyMarginTokens,
            1_024
        )
    }

    public var usesFallbackWindow: Bool { contextWindowTokens == nil }

    public static func conservative(
        contextWindowTokens: Int?,
        toolSchemaTokens: Int = 0
    ) -> Self {
        let window = contextWindowTokens ?? 32_000
        let outputReserve = min(max(window / 5, 8_000), 64_000)
        let safety = max(window / 20, 2_000)
        return Self(
            contextWindowTokens: contextWindowTokens,
            reservedOutputTokens: outputReserve,
            toolSchemaTokens: toolSchemaTokens,
            safetyMarginTokens: safety
        )
    }
}

public struct LLMContextPreparationRequest: Sendable, Equatable {
    public let conversationID: UUID
    public let providerID: String?
    public let model: String?
    public let budget: LLMContextBudget
    public let mode: LLMContextPreparationMode

    public init(
        conversationID: UUID,
        providerID: String? = nil,
        model: String? = nil,
        budget: LLMContextBudget,
        mode: LLMContextPreparationMode = .beforeSend
    ) {
        self.conversationID = conversationID
        self.providerID = providerID
        self.model = model
        self.budget = budget
        self.mode = mode
    }
}

public enum LLMContextEstimateSource: String, Sendable, Equatable {
    case exact
    case estimated
    case fallback
}

public struct LLMContextPreparationResult: Sendable, Equatable {
    public let messages: [Message]
    public let estimatedInputTokens: Int
    public let inputTokenLimit: Int
    public let estimateSource: LLMContextEstimateSource
    public let didCompact: Bool
    public let didFallback: Bool

    public init(
        messages: [Message],
        estimatedInputTokens: Int,
        inputTokenLimit: Int,
        estimateSource: LLMContextEstimateSource = .estimated,
        didCompact: Bool = false,
        didFallback: Bool = false
    ) {
        self.messages = messages
        self.estimatedInputTokens = estimatedInputTokens
        self.inputTokenLimit = inputTokenLimit
        self.estimateSource = estimateSource
        self.didCompact = didCompact
        self.didFallback = didFallback
    }
}

/// 一个保守、无 provider 依赖的 token 估算器。
public enum LLMContextTokenEstimator {
    /// 混合中文、代码和 JSON 时，按 UTF-8 字节数估算比字符数更保守。
    public static func estimate(text: String) -> Int {
        max(Int(ceil(Double(text.utf8.count) / 3.0)), 1)
    }

    public static func estimate(message: Message) -> Int {
        let content = estimate(text: message.content)
        let reasoning = message.reasoningContent.map(estimate(text:)) ?? 0
        let toolCalls = message.toolCalls?.reduce(0) { total, call in
            total + estimate(text: call.name) + estimate(text: call.arguments) + 12
        } ?? 0
        return content + reasoning + toolCalls + 12
    }

    public static func estimate(messages: [Message]) -> Int {
        messages.reduce(0) { $0 + estimate(message: $1) }
    }
}

/// 为一次 LLM 请求准备消息上下文。
///
/// 调用方不需要知道返回的是完整历史、摘要加最近消息，还是其他经过筛选的
/// 上下文。具体策略由实现方负责，完整聊天记录仍由 `MessageManaging` 保存。
@MainActor
public protocol LLMContextProviding: AnyObject, Sendable {
    func messagesForLLM(in conversationID: UUID) async -> [Message]

    func prepareContext(
        for request: LLMContextPreparationRequest
    ) async -> LLMContextPreparationResult

    func reportInputUsage(
        _ inputTokenCount: Int,
        for request: LLMContextPreparationRequest,
        estimatedInputTokens: Int
    )

    func reportContextLimitExceeded(
        for request: LLMContextPreparationRequest
    )
}

public extension LLMContextProviding {
    func prepareContext(
        for request: LLMContextPreparationRequest
    ) async -> LLMContextPreparationResult {
        let messages = await messagesForLLM(in: request.conversationID)
        return LLMContextPreparationResult(
            messages: messages,
            estimatedInputTokens: LLMContextTokenEstimator.estimate(messages: messages),
            inputTokenLimit: request.budget.inputTokenLimit,
            estimateSource: request.budget.usesFallbackWindow ? .fallback : .estimated
        )
    }

    func reportInputUsage(
        _ inputTokenCount: Int,
        for request: LLMContextPreparationRequest,
        estimatedInputTokens: Int
    ) {}

    func reportContextLimitExceeded(
        for request: LLMContextPreparationRequest
    ) {}
}

/// 不改变消息内容的透传实现。
///
/// 用于测试、宿主降级，以及上下文压缩插件尚未启用时保持原有行为。
@MainActor
public final class PassthroughLLMContextProvider: LLMContextProviding {
    private let messages: any MessageManaging

    public init(messages: any MessageManaging) {
        self.messages = messages
    }

    public func messagesForLLM(in conversationID: UUID) async -> [Message] {
        await messages.messagesForLLM(in: conversationID)
    }
}
