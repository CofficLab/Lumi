import KitAgentTool
import Foundation

/// OCR 插件的轻量本地化。
///
/// 不依赖外部 xcstrings，直接按语言偏好返回中英文文案。
public enum OcrLocalization {
    /// 按语言偏好返回文案。
    public static func localized(_ language: LanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .english: en
        case .chinese: zh
        }
    }

    /// 无语言上下文时的双语回退：按系统语言偏好返回。
    public static func string(_ en: String, _ zh: String) -> String {
        localized(LanguagePreference.current, en: en, zh: zh)
    }
}
