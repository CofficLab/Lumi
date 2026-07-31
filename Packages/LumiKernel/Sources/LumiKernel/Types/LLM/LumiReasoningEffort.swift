import Foundation

public enum LumiReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic = "auto"
    case minimal
    case low
    case medium
    case high

    public static let defaultEffort: LumiReasoningEffort = .automatic

    public var id: String { rawValue }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "auto", "automatic": self = .automatic
        case "minimal", "min": self = .minimal
        case "low": self = .low
        case "medium", "med": self = .medium
        case "high": self = .high
        default: return nil
        }
    }

    public var levelCode: String {
        switch self {
        case .automatic: "AUTO"
        case .minimal: "MIN"
        case .low: "LOW"
        case .medium: "MED"
        case .high: "HIGH"
        }
    }

    public var displayName: String {
        switch self {
        case .automatic: "自动"
        case .minimal: "极简"
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        }
    }

    public var iconName: String {
        switch self {
        case .automatic: "sparkles"
        case .minimal: "bolt"
        case .low: "gauge.low"
        case .medium: "gauge.medium"
        case .high: "gauge.high"
        }
    }

    public var description: String {
        switch self {
        case .automatic: "让模型或供应商决定推理预算"
        case .minimal: "尽量减少推理，适合简单问答"
        case .low: "轻量推理，兼顾速度和质量"
        case .medium: "标准推理，适合一般复杂任务"
        case .high: "更高推理预算，适合代码、架构和调试"
        }
    }
}

public struct LumiLLMGenerationOptions: Codable, Equatable, Sendable {
    public var reasoningEffort: LumiReasoningEffort?

    public init(reasoningEffort: LumiReasoningEffort? = nil) {
        self.reasoningEffort = reasoningEffort
    }
}
