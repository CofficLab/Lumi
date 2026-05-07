import Foundation

extension Notification.Name {
    /// Lumi 全局主题切换通知（App + Editor 一体化）。
    /// userInfo:
    /// - themeId: String
    /// - editorThemeId: String
    static let lumiThemeDidChange = Notification.Name("lumiThemeDidChange")
}
