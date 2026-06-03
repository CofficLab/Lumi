import Foundation

/// 语言偏好
public enum LanguagePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case chinese = "zh"
    case english = "en"

    public var id: String { rawValue }

    public init(locale: Locale) {
        let languageCode = locale.language.languageCode?.identifier ?? locale.identifier
        if languageCode.lowercased().hasPrefix("zh") {
            self = .chinese
        } else {
            self = .english
        }
    }

    public static var current: LanguagePreference {
        LanguagePreference(locale: .current)
    }

    public var localeIdentifier: String {
        switch self {
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    public var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    /// 显示名称（支持多语言）
    public var displayName: String {
        switch self {
        case .chinese:
            return String(localized: "Chinese", bundle: .module)
        case .english:
            return String(localized: "English", bundle: .module)
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
