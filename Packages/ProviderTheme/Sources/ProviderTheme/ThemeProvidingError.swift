import Foundation

/// 主题管理错误。
///
/// 复刻旧版 Lumi（`LumiUI.ThemeError`）的错误语义。
public enum ThemeProvidingError: Error, Equatable, Sendable {
    /// 未注册任何主题。
    case noThemesRegistered
    /// 注册了重复的主题 id。
    case duplicateThemeId(String)
    /// 尝试选中不存在的主题 id。
    case unknownThemeId(String)
}
