import Foundation

/// 响应详细程度
///
/// 定义 LLM 返回消息的详细程度级别。
/// 用户可根据场景选择 V1/V2/V3，数字越大表示回复越详细。
public enum ResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    /// V1 - 只返回核心结论，省略推理过程
    case brief

    /// V2 - 默认详细度，包含必要说明和步骤
    case standard

    /// V3 - 包含完整推理过程、代码上下文和补充说明
    case detailed

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .brief:
            return "v1"
        case .standard:
            return "v2"
        case .detailed:
            return "v3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "v1", "brief":
            self = .brief
        case "v2", "standard", "normal":
            self = .standard
        case "v3", "detailed":
            self = .detailed
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid response verbosity: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// 等级标识
    public var levelCode: String {
        rawValue.uppercased()
    }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .brief:
            return "简洁"
        case .standard:
            return "标准"
        case .detailed:
            return "详细"
        }
    }

    /// 英文显示名称
    public var displayNameEn: String {
        switch self {
        case .brief:
            return "Brief"
        case .standard:
            return "Standard"
        case .detailed:
            return "Detailed"
        }
    }

    /// 图标
    public var iconName: String {
        switch self {
        case .brief:
            return "text.alignleft"
        case .standard:
            return "text.justify.left"
        case .detailed:
            return "doc.richtext"
        }
    }

    /// 描述
    public var description: String {
        switch self {
        case .brief:
            return "只返回核心结论"
        case .standard:
            return "包含必要说明和步骤"
        case .detailed:
            return "包含完整推理和上下文"
        }
    }

    /// 描述英文
    public var descriptionEn: String {
        switch self {
        case .brief:
            return "Core conclusions only"
        case .standard:
            return "Essential explanation and steps"
        case .detailed:
            return "Full reasoning and context"
        }
    }

    /// 系统提示词片段
    ///
    /// 用于注入到 LLM 请求的 system prompt 中，指导模型调整回复风格。
    public var systemPromptFragment: String {
        switch self {
        case .brief:
            return "Be concise. Provide only the essential answer without explanation."
        case .standard:
            return "Use a balanced level of detail. Include the answer, key reasoning, and necessary steps without excessive background."
        case .detailed:
            return "Be thorough. Include reasoning steps, relevant context, and potential caveats."
        }
    }
}
