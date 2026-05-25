import Foundation

/// 响应详细程度
///
/// 定义 LLM 返回消息的详细程度级别。
/// 用户可根据场景选择简洁或详细的回复风格。
public enum ResponseVerbosity: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 简洁模式 - 只返回核心结论，省略推理过程
    case brief = "brief"

    /// 详细模式 - 包含完整推理过程、代码上下文和补充说明
    case detailed = "detailed"

    public var id: String { rawValue }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .brief:
            return "简洁"
        case .detailed:
            return "详细"
        }
    }

    /// 英文显示名称
    public var displayNameEn: String {
        switch self {
        case .brief:
            return "Brief"
        case .detailed:
            return "Detailed"
        }
    }

    /// 图标
    public var iconName: String {
        switch self {
        case .brief:
            return "text.alignleft"
        case .detailed:
            return "doc.richtext"
        }
    }

    /// 描述
    public var description: String {
        switch self {
        case .brief:
            return "只返回核心结论"
        case .detailed:
            return "包含完整推理和上下文"
        }
    }

    /// 描述英文
    public var descriptionEn: String {
        switch self {
        case .brief:
            return "Core conclusions only"
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
        case .detailed:
            return "Be thorough. Include reasoning steps, relevant context, and potential caveats."
        }
    }
}
