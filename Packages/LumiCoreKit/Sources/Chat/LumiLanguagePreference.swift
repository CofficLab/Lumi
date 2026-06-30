import Foundation

/// 用户语言偏好。
///
/// 插件 SDK 中统一的轻量语言表示，供工具实现按用户语言返回本地化描述、提示或错误。
/// 取代历史上由 `AgentToolKit.LanguagePreference` + `__lumi_language` 参数注入的做法——
/// 原生 `LumiAgentTool` 直接通过 `LumiToolExecutionContext.language` 获取。
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

    /// 对应的 `Locale` 标识符，可用于 `String(localized:bundle:locale:)` 等本地化 API。
    public var localeIdentifier: String {
        switch self {
        case .chinese: "zh-Hans"
        case .english: "en"
        }
    }

    public var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    /// 按语言返回两段文案之一，常用于工具的 `displayDescription` / 错误信息。
    public func localized(en: String, zh: String) -> String {
        switch self {
        case .chinese: zh
        case .english: en
        }
    }
}
