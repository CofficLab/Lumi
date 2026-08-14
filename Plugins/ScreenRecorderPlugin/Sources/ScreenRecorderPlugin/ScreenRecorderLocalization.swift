import Foundation
import KernelLumi

/// 屏幕录制插件的轻量本地化。
///
/// 不依赖外部 xcstrings，直接按内核语言偏好返回中英文文案，与 `MindMapLocalization`
/// 的内联模式一致，便于在工具与视图中共用。
public enum ScreenRecorderLocalization {
    /// 按当前内核语言偏好返回文案。
    public static func localized(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .english: en
        case .chinese: zh
        }
    }

    /// 无内核上下文时的双语回退：按系统语言偏好返回。
    public static func string(_ en: String, _ zh: String) -> String {
        localized(LumiLanguagePreference.current, en: en, zh: zh)
    }

    /// 用于 UI 文案：按系统语言偏好返回（无内核上下文时调用）。
    public static func ui(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
}
