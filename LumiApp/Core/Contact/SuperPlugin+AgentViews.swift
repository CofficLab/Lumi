import AppKit
import SwiftUI
import Foundation

/// Agent 模式视图扩展
///
/// 为 Agent 模式视图方法提供默认实现。
/// 插件可以选择性地实现这些方法来贡献 UI。
///
/// ## Agent 模式布局结构
///
/// ```
/// ┌─────────────────────────────────────────────────────┐
/// │  SidebarView    │  Detail Column                    │
/// │  (侧边栏)       │  ┌─────────────────────────┐      │
/// │                 │  │  DetailHeaderView       │      │
/// │                 │  │  (详情栏头部)           │      │
/// │                 │  ├─────────────────────────┤      │
/// │                 │  │  DetailMiddleView       │      │
/// │                 │  │  (详情栏中间)           │      │
/// │                 │  ├─────────────────────────┤      │
/// │                 │  │  DetailBottomView       │      │
/// │                 │  │  (详情栏底部)           │      │
/// │                 │  └─────────────────────────┘      │
/// ├─────────────────────────────────────────────────────┤
/// │  RightView (右侧栏，如文件预览)                      │
/// ├─────────────────────────────────────────────────────┤
/// │  StatusBarView (底部状态栏)                          │
/// └─────────────────────────────────────────────────────┘
/// ```
extension SuperPlugin {
    /// 默认实现：不提供侧边栏视图
    @MainActor func addSidebarView() -> AnyView? { nil }

    /// 默认实现：不提供右侧栏视图
    @MainActor func addRightView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏头部视图
    @MainActor func addDetailHeaderView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏中间视图
    @MainActor func addDetailMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏底部视图
    @MainActor func addDetailBottomView() -> AnyView? { nil }

    /// 默认实现：不提供状态栏视图
    @MainActor func addStatusBarView() -> AnyView? { nil }
}
