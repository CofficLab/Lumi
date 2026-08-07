import Foundation

public enum LumiReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case low
    case high
    case xhigh
    case max

    public static let defaultEffort: LumiReasoningEffort = .high

    public var id: String { rawValue }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "low": self = .low
        case "high": self = .high
        case "xhigh": self = .xhigh
        case "max": self = .max
        default: return nil
        }
    }

    public var levelCode: String {
        switch self {
        case .low: "LOW"
        case .high: "HIGH"
        case .xhigh: "XHIGH"
        case .max: "MAX"
        }
    }

    public var displayName: String {
        switch self {
        case .low: "低"
        case .high: "高"
        case .xhigh: "超高"
        case .max: "极限"
        }
    }

    public var iconName: String {
        switch self {
        case .low: "gauge.low"
        case .high: "gauge.medium"
        case .xhigh: "gauge.high"
        case .max: "flame.fill"
        }
    }

    public var description: String {
        switch self {
        case .low: "轻量推理，适合简单问答"
        case .high: "标准推理，适合一般任务"
        case .xhigh: "深度推理，适合复杂代码和架构"
        case .max: "最大推理预算，适合极致调试和难题"
        }
    }
}

public struct LumiLLMGenerationOptions: Codable, Equatable, Sendable {
    public var reasoningEffort: LumiReasoningEffort?

    public init(reasoningEffort: LumiReasoningEffort? = nil) {
        self.reasoningEffort = reasoningEffort
    }
}
