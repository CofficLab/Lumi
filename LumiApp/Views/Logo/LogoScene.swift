import SwiftUI

/// Logo 使用场景
///
/// 定义 Logo 在不同 UI 位置下的渲染方式。
enum LogoScene: String, CaseIterable {
    /// 通用场景
    case general
    /// App 图标
    case appIcon
    /// 关于窗口
    case about
    /// 菜单栏（未激活）
    case statusBarInactive
    /// 菜单栏（已激活）
    case statusBarActive
}
