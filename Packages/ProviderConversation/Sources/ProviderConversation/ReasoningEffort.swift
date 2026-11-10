import Foundation

/// 请求级「具体推理档位」，与模型能力枚举（`LumiThinkingAndReasoning`）解耦：
/// 该类型描述用户本次请求的具体档位（low / medium / high / xhigh / max）。
public enum ReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max

    public static let defaultEffort: ReasoningEffort = .high

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

    public var iconName: String {
        switch self {
        case .low: "gauge.low"
        case .medium: "gauge.with.needle"
        case .high: "gauge.medium"
        case .xhigh: "gauge.high"
        case .max: "flame.fill"
        }
    }
}
