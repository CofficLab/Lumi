import Foundation

public extension Notification.Name {
    /// 菜单栏有效外观变化（系统主题、壁纸亮度自适应等）。插件可监听并重绘 template 图表。
    static let lumiMenuBarAppearanceDidChange = Notification.Name("lumiMenuBarAppearanceDidChange")
}
