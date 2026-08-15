import Foundation

/// Logo 显示场景
///
/// 不同的场景可能有不同的视觉要求和动画行为。
/// 这是精简内核（KernelCore 体系）下的轻量版本，仅保留当前宿主
/// （LumiMinimalApp 等）实际用到的场景。
public enum LogoScene: String, CaseIterable, Sendable {
    /// 通用场景（默认）
    case general
    /// 系统菜单栏图标：恒为单色模板图（由系统统一着色），无动画。
    case statusBar
    /// 系统菜单栏图标：Logo 当前处于需要提醒用户的高亮状态。
    case statusBarHighlighted
}
