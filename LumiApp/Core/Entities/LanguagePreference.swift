import Foundation

/// 语言偏好
public enum LanguagePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case chinese = "zh"
    case english = "en"

    public var id: String { rawValue }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    /// 本地化名称
    public var localizedName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    /// 系统提示中的语言描述
    public var systemPromptDescription: String {
        switch self {
        case .chinese:
            return "User Language: Chinese (用户偏好中文，请用中文回复)"
        case .english:
            return "User Language: English (User prefers English)"
        }
    }
}
