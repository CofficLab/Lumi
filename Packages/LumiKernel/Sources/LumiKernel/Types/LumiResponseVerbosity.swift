import Foundation

public enum LumiResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case brief
    case standard
    case detailed

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

    public var displayName: String {
        switch self { case .brief: "简洁"; case .standard: "标准"; case .detailed: "详细" }
    }

    public var iconName: String {
        switch self {
        case .brief: "text.alignleft"
        case .standard: "text.justify.left"
        case .detailed: "doc.richtext"
        }
    }

    public var description: String {
        switch self {
        case .brief: "只返回核心结论"
        case .standard: "包含必要说明和步骤"
        case .detailed: "包含完整推理和上下文"
        }
    }
}
