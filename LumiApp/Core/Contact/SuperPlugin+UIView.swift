import AppKit
import SwiftUI

// MARK: - UI View Methods

extension SuperPlugin {
    /// 添加根视图包裹
    ///
    /// 允许插件包裹整个应用的内容视图，实现全局拦截、修饰等功能。
    /// 此方法在视图层次的最外层执行，可以用于：
    /// - 添加全局 overlay
    /// - 拦截手势事件
    /// - 应用全局样式
    ///
    /// - Parameter content: 要被包裹的原始内容视图
    /// - Returns: 包裹后的视图，如果不需要则返回 nil
    ///
    /// ## 注意
    ///
    /// 多个插件的根视图包裹会按照插件注册顺序依次执行，
    /// 外层包裹先执行，内层包裹后执行。
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View

    /// 添加工具栏前导视图
    ///
    /// 在主窗口工具栏的左侧添加自定义视图。
    /// 常用于：
    /// - 导航按钮
    /// - 快捷操作
    /// - 自定义标题区域
    ///
    /// - Returns: 要添加到工具栏前导的视图，如果不需要则返回 nil
    @MainActor func addToolBarLeadingView() -> AnyView?

    /// 添加工具栏右侧视图
    ///
    /// 在主窗口工具栏的右侧添加自定义视图。
    /// 常用于：
    /// - 设置按钮
    /// - 帮助按钮
    /// - 用户头像
    ///
    /// - Returns: 要添加到工具栏右侧的视图，如果不需要则返回 nil
    @MainActor func addToolBarTrailingView() -> AnyView?

    /// 添加详情视图
    ///
    /// 在应用主内容区域添加详情视图。
    /// 通常用于显示选中项的详细信息。
    ///
    /// - Returns: 要添加的详情视图，如果不需要则返回 nil
    @MainActor func addDetailView() -> AnyView?

    /// 添加设置视图
    ///
    /// 在设置面板中添加插件的配置界面。
    /// 如果插件需要用户配置选项，应实现此方法。
    ///
    /// - Returns: 要添加的设置视图，如果不需要则返回 nil
    @MainActor func addSettingsView() -> AnyView?

    /// 提供导航入口（用于侧边栏导航）
    ///
    /// 在侧边栏中添加导航项，点击后可切换到对应的内容视图。
    /// 可以返回多个导航项来创建嵌套结构。
    ///
    /// - Returns: 导航入口数组，如果不需要则返回 nil
    @MainActor func addNavigationEntries() -> [NavigationEntry]?

    /// 添加状态栏弹窗视图
    ///
    /// 当用户点击菜单栏图标时显示的弹出视图。
    /// 常用于：
    /// - 快速操作面板
    /// - 状态摘要
    /// - 快捷设置
    ///
    /// - Returns: 要添加到状态栏弹窗的视图，如果不需要则返回 nil
    @MainActor func addStatusBarPopupView() -> AnyView?

    /// 添加状态栏内容视图
    ///
    /// 直接显示在菜单栏图标位置的视图。
    /// 与弹窗视图不同，内容视图始终可见。
    /// 常用于：
    /// - 实时状态指示器
    /// - 动态图标
    /// - 简短数据展示
    ///
    /// - Returns: 要显示在状态栏图标位置的视图，如果不需要则返回 nil
    /// - Note: 插件可以提供自定义的状态栏内容视图，内核会将其组合显示
    @MainActor func addStatusBarContentView() -> AnyView?
}

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
    @MainActor func addToolBarLeadingView() -> AnyView? { nil }

    /// 默认实现：不提供工具栏右侧视图
    @MainActor func addToolBarTrailingView() -> AnyView? { nil }

    /// 默认实现：不提供详情视图
    @MainActor func addDetailView() -> AnyView? { nil }

    /// 默认实现：不提供设置视图
    @MainActor func addSettingsView() -> AnyView? { nil }

    /// 默认实现：不提供导航入口
    @MainActor func addNavigationEntries() -> [NavigationEntry]? { nil }

    /// 默认实现：不提供弹窗视图
    @MainActor func addStatusBarPopupView() -> AnyView? { nil }

    /// 默认实现：不提供状态栏内容视图
    @MainActor func addStatusBarContentView() -> AnyView? { nil }
}
