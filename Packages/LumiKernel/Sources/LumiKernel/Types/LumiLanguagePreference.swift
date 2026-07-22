import Foundation

/// 用户语言偏好。
///
/// 供工具实现按用户语言返回本地化描述、提示或错误。
public enum LumiLanguagePreference: String, Sendable, Equatable, CaseIterable {
    case chinese = "zh"
    case english = "en"

    /// 根据系统 `Locale` 推断语言偏好。
    public init(locale: Locale) {
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        self = code.lowercased().hasPrefix("zh") ? .chinese : .english
    }

    public static var current: LumiLanguagePreference {
        LumiLanguagePreference(locale: .current)
    }

    /// 对应的 `Locale` 标识符。
    public var localeIdentifier: String {
        switch self {
        case .chinese: "zh-Hans"
        case .english: "en"
        }
    }

    public var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    /// 按语言返回两段文案之一。
    public func localized(en: String, zh: String) -> String {
        switch self {
        case .chinese: zh
        case .english: en
        }
    }

    public var iconName: String {
        "character.book.closed"
    }
}