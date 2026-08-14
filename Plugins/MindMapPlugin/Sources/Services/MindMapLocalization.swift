import Foundation
import KernelLumi

/// 思维导图插件的轻量本地化。
///
/// 不依赖外部 xcstrings，直接按内核语言偏好返回中英文文案，与 `IconToolSupport.localized`
/// 的内联模式一致，便于在工具与视图中共用。
public enum MindMapLocalization {
    /// 按当前内核语言偏好返回文案。
    public static func localized(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .english: en
        case .chinese: zh
        }
    }

    /// 不依赖内核时的固定双语回退（默认英文）。
    public static func string(_ en: String, _ zh: String) -> String {
        en
    }
}
