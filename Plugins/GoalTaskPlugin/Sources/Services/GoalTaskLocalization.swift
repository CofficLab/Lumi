import Foundation

/// GoalTask 插件的国际化支持
///
/// 提供本地化字符串访问，支持中文和英文。
public enum GoalTaskLocalization {
    /// 获取本地化字符串
    public static func string(_ key: String, bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}