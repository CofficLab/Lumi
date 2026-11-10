import Foundation

/// 回复详细程度。
public enum ResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case brief
    case standard
    case detailed
    /// ZCode 风格消息列表（V4）。
    ///
    /// 这是**呈现变体**，不是回复长度策略：它只决定消息列表的外观，
    /// 不得影响提示词、回复长度或 Agent 执行。
    case zcode

    /// 未显式指定时使用的默认级别（单一事实来源）。
    /// 所有回退到默认值的位置都应引用此处，避免各处不一致。
    public static let defaultVerbosity: ResponseVerbosity = .standard

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .brief: "v1"
        case .standard: "v2"
        case .detailed: "v3"
        case .zcode: "v4"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "v1", "brief": self = .brief
        case "v2", "standard", "normal": self = .standard
        case "v3", "detailed": self = .detailed
        case "v4", "zcode": self = .zcode
        default: return nil
        }
    }

    public var levelCode: String { rawValue.uppercased() }

    // Important: `displayName` / `description` 已被 #920 移除 ——
    //   用户可见文案改由 `PluginConversationVerbosity.VerbosityLocalization`
    //   维护（多语言），`ProviderConversation` 不再产出任何语言的显示名。
    //   V4 的 ZCode 文案同样在那里补齐。
    public var iconName: String {
        switch self {
        // A checkmark makes the concise, conclusion-first mode visibly
        // different from the text-layout icons used by the richer modes.
        case .brief: "checkmark.circle"
        case .standard: "text.justify.left"
        case .detailed: "doc.richtext"
        case .zcode: "bubble.left.and.bubble.right"
        }
    }
}
