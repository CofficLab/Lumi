import AppKit
import SwiftUI

// MARK: - UI View Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供根视图包裹
    ///
    /// 返回 nil 表示不包裹根视图。
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View { nil }

    /// 提供根视图（接收 AnyView 参数的便捷方法）
    ///
    /// 内部调用 `addRootView`，将 AnyView 转换为 ViewBuilder。
    @MainActor func provideRootView(_ content: AnyView) -> AnyView? {
        self.addRootView { content }
    }

    /// 包裹根视图（安全版本）
    ///
    /// 如果插件提供了根视图包装，则返回包装后的视图；
    /// 否则返回原始视图。
    ///
    /// - Parameter content: 要包裹的视图
    /// - Returns: 包裹后的视图
    @MainActor func wrapRoot(_ content: AnyView) -> AnyView {
        if let wrapped = self.provideRootView(content) {
            return wrapped
        }
        return content
    }

    /// 默认实现：不提供工具栏前导视图
    @MainActor func addToolBarLeadingView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供工具栏中间视图
    @MainActor func addToolBarCenterView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供工具栏右侧视图
    @MainActor func addToolBarTrailingView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供面板图标（使用插件默认 iconName）
    nonisolated func addPanelIcon() -> String? { nil }

    /// 默认实现：不提供面板视图
    @MainActor func addPanelView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供 Panel Header 视图
    @MainActor func addPanelHeaderView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供 Rail 标签页
    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] { [] }

    /// 默认实现：不提供 Rail 内容视图
    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供右侧栏视图
    @MainActor func addSidebarView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供设置视图
    @MainActor func addSettingsView() -> AnyView? { nil }

    /// 默认实现：不提供弹窗视图列表（兼容旧版 `addStatusBarPopupView`）
    @MainActor func addStatusBarPopupViews() -> [AnyView] {
        if let view = addStatusBarPopupView() {
            return [view]
        }
        return []
    }

    /// 默认实现：不提供弹窗视图
    @available(*, deprecated, message: "Use addStatusBarPopupViews() returning [AnyView] instead")
    @MainActor func addStatusBarPopupView() -> AnyView? { nil }

    /// 默认实现：不提供状态栏内容视图
    @MainActor func addStatusBarContentView() -> AnyView? { nil }

    /// 默认实现：不提供主题贡献
    @MainActor func addThemeContributions() -> [LumiThemeContribution] { [] }
}
