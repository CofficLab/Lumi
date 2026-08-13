import Foundation

// MARK: - LumiReasoningEffort

/// 请求级"具体推理档位"，与 `LumiThinkingAndReasoning`（模型能力枚举）解耦：
/// - `LumiThinkingAndReasoning` 描述模型**能力**（支持几档、是否开关）。
/// - `LumiReasoningEffort` 描述用户**本次请求的具体档位**（low / medium / high / xhigh / max）。
///
/// 两者通过 `LumiReasoningEffort.available(for:)` 桥接：消费端用模型能力过滤档位集合，
/// Provider 端把具体档位的 `rawValue` 写进 wire 格式。
public enum LumiReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max

    public static let defaultEffort: LumiReasoningEffort = .high

    public var id: String { rawValue }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "xhigh": self = .xhigh
        case "max": self = .max
        default: return nil
        }
    }

    public var levelCode: String {
        switch self {
        case .low: "LOW"
        case .medium: "MED"
        case .high: "HIGH"
        case .xhigh: "XHIGH"
        case .max: "MAX"
        }
    }

    public var displayName: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        case .xhigh: "超高"
        case .max: "极限"
        }
    }

    public var iconName: String {
        switch self {
        case .low: "gauge.low"
        case .medium: "gauge.with.needle"
        case .high: "gauge.medium"
        case .xhigh: "gauge.high"
        case .max: "flame.fill"
        }
    }

    public var description: String {
        switch self {
        case .low: "轻量推理，适合简单问答"
        case .medium: "标准推理，适合一般任务"
        case .high: "深度推理，适合复杂代码和架构"
        case .xhigh: "更高推理预算，适合硬骨头"
        case .max: "最大推理预算，适合极致调试和难题"
        }
    }
}

// MARK: - LumiLLMRequest

/// 一次 LLM 请求的完整描述，包含消息内容、模型选择、工具定义、附件以及所有可选生成参数。
public struct LumiLLMRequest: Sendable {
    // MARK: - 核心字段
    public let messages: [LumiChatMessage]
    public let model: String
    public let tools: [any LumiAgentTool]
    public let imageAttachments: [LumiImageAttachment]
    public let fileAttachments: [LumiFileAttachment]

    // MARK: - 生成参数（所有字段语义均为"nil 表示使用服务端/模型默认"）
    /// 本次请求的具体推理档位（与模型能力枚举 `LumiThinkingAndReasoning` 解耦）。
    ///
    /// 字段语义：
    /// - `nil`：使用服务端默认行为。
    /// - `.low` / `.medium` / `.high` / `.xhigh` / `.max`：用户选定的具体档位，
    ///   由 Provider 把 `rawValue` 写进 wire 格式（如 OpenAI `reasoning_effort`、
    ///   Anthropic `thinking.budget_tokens` 映射）。
    public var reasoningEffort: LumiReasoningEffort?
    /// Temperature [0, 2]. nil means use model default.
    public var temperature: Double?
    /// Nucleus sampling [0, 1]. nil means use model default.
    public var topP: Double?
    /// Max output tokens. nil means use model default.
    public var maxTokens: Int?
    /// Service tier — "standard" or "priority" (1.5x price, priority admission).
    public var serviceTier: String?
    /// Tool choice — "auto" or "none".
    public var toolChoice: String?
    /// User ID for usage aggregation / rate-limit analysis.
    public var userID: String?

    public init(
        messages: [LumiChatMessage],
        model: String,
        tools: [any LumiAgentTool] = [],
        imageAttachments: [LumiImageAttachment] = [],
        fileAttachments: [LumiFileAttachment] = [],
        reasoningEffort: LumiReasoningEffort? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        serviceTier: String? = nil,
        toolChoice: String? = nil,
        userID: String? = nil
    ) {
        self.messages = messages
        self.model = model
        self.tools = tools
        self.imageAttachments = imageAttachments
        self.fileAttachments = fileAttachments
        self.reasoningEffort = reasoningEffort
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.serviceTier = serviceTier
        self.toolChoice = toolChoice
        self.userID = userID
    }
}
