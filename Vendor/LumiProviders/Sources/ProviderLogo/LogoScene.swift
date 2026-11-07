import Foundation

/// Logo 显示场景
///
/// 不同的场景可能有不同的视觉要求和动画行为。
/// 这是精简内核（KernelCore 体系）下的轻量版本，仅保留宿主实际用到的场景。
public enum LogoScene: String, CaseIterable, Sendable {
    /// Dock / App Icon 预览 / 大尺寸展示：允许彩色与动画。
    case appIcon
    /// 通用场景（默认）
    case general
    /// 关于页 / 设置页顶部等展示场景：允许彩色与动画。
    case about
    /// 系统菜单栏图标：恒为单色模板图（由系统统一着色），无动画。
    case statusBar
    /// 系统菜单栏图标：Logo 当前处于需要提醒用户的高亮状态。
    case statusBarHighlighted
}
