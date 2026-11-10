import Foundation

/// 回复详细程度。
public enum ResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case brief
    case standard
    case detailed

    /// 未显式指定时使用的默认级别（单一事实来源）。
    /// 所有回退到默认值的位置都应引用此处，避免各处不一致。
    public static let defaultVerbosity: ResponseVerbosity = .standard

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .brief: "v1"
        case .standard: "v2"
        case .detailed: "v3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "v1", "brief": self = .brief
        case "v2", "standard", "normal": self = .standard
        case "v3", "detailed": self = .detailed
        default: return nil
        }
    }

    public var levelCode: String { rawValue.uppercased() }

    public var iconName: String {
        switch self {
        // A checkmark makes the concise, conclusion-first mode visibly
        // different from the text-layout icons used by the richer modes.
        case .brief: "checkmark.circle"
        case .standard: "text.justify.left"
        case .detailed: "doc.richtext"
        }
    }
}
