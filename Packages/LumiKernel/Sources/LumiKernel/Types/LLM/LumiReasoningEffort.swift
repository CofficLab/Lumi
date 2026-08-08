import Foundation

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

extension LumiReasoningEffort {
    /// 仅"3 档模型"（如 OpenAI GPT-5 / o-series）支持的档位集合：
    /// `low / medium / high`。
    public static let threeLevels: [LumiReasoningEffort] = [.low, .medium, .high]

    /// "4 档模型"（如 Anthropic / DeepSeek V4 / Qwen3）支持的档位集合：
    /// `low / high / xhigh / max`（注意：跳过 `medium`）。
    public static let fourLevels: [LumiReasoningEffort] = [.low, .high, .xhigh, .max]

    /// 根据模型能力枚举，返回该模型可用的推理档位。
    ///
    /// - Parameter support: 模型的能力声明（`unsupported` 表示模型不支持思考）。
    /// - Returns: 对应档位集合；`unsupported` 返回空数组。
    public static func available(for support: LumiThinkingSupport) -> [LumiReasoningEffort] {
        switch support {
        case .unsupported: []
        case .threeLevel: threeLevels
        case .fourLevel: fourLevels
        }
    }
}

/// Controls MiniMax's thinking output via the Anthropic-compatible `thinking` parameter.
public enum MiniMaxThinkingOption: String, Codable, Equatable, Sendable {
    /// Disable thinking output for MiniMax-M3. M2.x models always have thinking on.
    case disabled
    /// Enable thinking output and return thinking content block.
    case adaptive
}

public struct LumiLLMGenerationOptions: Codable, Equatable, Sendable {
    public var reasoningEffort: LumiReasoningEffort?
    /// MiniMax/MiniMax-M3: `thinking.type` — "disabled" or "adaptive".
    /// M2.x models always have thinking on; set to nil for non-MiniMax models.
    public var miniMaxThinking: MiniMaxThinkingOption?
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
        reasoningEffort: LumiReasoningEffort? = nil,
        miniMaxThinking: MiniMaxThinkingOption? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        serviceTier: String? = nil,
        toolChoice: String? = nil,
        userID: String? = nil
    ) {
        self.reasoningEffort = reasoningEffort
        self.miniMaxThinking = miniMaxThinking
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.serviceTier = serviceTier
        self.toolChoice = toolChoice
        self.userID = userID
    }
}
