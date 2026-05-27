import AppKit
import LumiUI
import SwiftUI

// MARK: - UI View Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供根视图包裹
    @MainActor public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View { nil }

    /// 提供根视图（接收 AnyView 参数的便捷方法）
    @MainActor public func provideRootView(_ content: AnyView) -> AnyView? {
        self.addRootView { content }
    }

    /// 包裹根视图（安全版本）
    @MainActor public func wrapRoot(_ content: AnyView) -> AnyView {
        if let wrapped = self.provideRootView(content) {
            return wrapped
        }
        return content
    }

    /// 默认实现：不包裹右侧栏根视图
    @MainActor public func wrapRightSidebarRoot(_ content: AnyView, activeIcon: String?) -> AnyView {
        content
    }

    /// 默认实现：不提供工具栏前导视图
    @MainActor public func addToolBarLeadingView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供工具栏中间视图
    @MainActor public func addToolBarCenterView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供工具栏右侧视图
    @MainActor public func addToolBarTrailingView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供 Activity Bar 视图容器
    @MainActor public func addViewContainer() -> ViewContainerItem? { nil }

    /// 默认实现：不提供 Panel Header 视图
    @MainActor public func addPanelHeaderView(activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供底部面板标签页
    @MainActor public func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] { [] }

    /// 默认实现：不提供底部面板内容视图
    @MainActor public func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供 Rail 标签页
    @MainActor public func addRailTabs(activeIcon: String?) -> [RailTab] { [] }

    /// 默认实现：不提供 Rail 内容视图
    @MainActor public func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供右侧栏 Section 视图
    @MainActor public func addSidebarSections(activeIcon: String?) -> [AnyView] { [] }

    /// 默认实现：不提供右侧栏底部工具栏左侧项
    @MainActor public func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] { [] }

    /// 默认实现：不提供右侧栏底部工具栏右侧项
    @MainActor public func addSidebarTrailingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] { [] }

    /// 默认实现：不提供右侧栏工具栏项的自定义按钮视图
    @MainActor public func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? { nil }

    /// 默认实现：不提供设置视图
    @MainActor public func addSettingsView() -> AnyView? { nil }

    /// 默认实现：不提供菜单栏弹窗视图列表（兼容旧版 `addMenuBarPopupView`）
    @MainActor public func addMenuBarPopupViews() -> [AnyView] {
        if let view = addMenuBarPopupView() {
            return [view]
        }
        return []
    }

    /// 默认实现：不提供菜单栏弹窗视图
    @available(*, deprecated, message: "Use addMenuBarPopupViews() returning [AnyView] instead")
    @MainActor public func addMenuBarPopupView() -> AnyView? { nil }

    /// 默认实现：不提供菜单栏内容视图
    @MainActor public func addMenuBarContentView() -> AnyView? { nil }

    /// 默认实现：不提供主题贡献
    @MainActor public func addThemeContributions() -> [LumiUIThemeContribution] { [] }
}
