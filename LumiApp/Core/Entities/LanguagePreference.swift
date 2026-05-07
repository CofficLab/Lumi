import Foundation

/// 语言偏好
public enum LanguagePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case chinese = "zh"
    case english = "en"

    public var id: String { rawValue }

    /// 显示名称（支持多语言）
    public var displayName: String {
        switch self {
        case .chinese:
            return String(localized: "Chinese", table: "AgentLanguageHeader")
        case .english:
            return String(localized: "English", table: "AgentLanguageHeader")
        }
    }

    /// 系统提示中的语言描述
    public var systemPromptDescription: String {
        switch self {
        case .chinese:
            return "语言偏好: 中文 (用户偏好中文，请用中文回复)"
        case .english:
            return "User Language: English (User prefers English)"
        }
    }
}
