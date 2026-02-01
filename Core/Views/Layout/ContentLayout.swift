import SwiftUI

/// 应用程序的主视图组件
/// 提供便捷的初始化方法和修饰符来配置 ContentView 的行为
struct ContentLayout: View {
    /// 应用状态提供者环境对象
    @EnvironmentObject var app: AppProvider

    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    /// 当前选中的标签页
    private(set) var tab: String?

    /// 导航分栏视图的列可见性
    private(set) var columnVisibility: NavigationSplitViewVisibility?

    /// 状态栏是否可见
    private(set) var statusBarVisibility: Bool?

    /// 工具栏是否可见
    private(set) var toolbarVisibility: Bool?

    /// 标签页选择器是否可见
    private(set) var tabPickerVisibility: Bool?

    /// 初始选中的标签页
    private(set) var initialTab: String?

    /// 初始选中的导航 ID
    private(set) var initialNavigationId: String?

    /// 初始化内容布局
    /// - Parameters:
    ///   - statusBarVisibility: 状态栏可见性
    ///   - initialColumnVisibility: 初始列可见性
    ///   - toolbarVisibility: 工具栏可见性
    ///   - tabPickerVisibility: 标签页选择器可见性
    ///   - initialTab: 初始标签页
    ///   - initialNavigationId: 初始导航 ID
    init(
        statusBarVisibility: Bool? = nil,
        initialColumnVisibility: NavigationSplitViewVisibility? = nil,
        toolbarVisibility: Bool? = nil,
        tabPickerVisibility: Bool? = nil,
        initialTab: String? = nil,
        initialNavigationId: String? = nil
    ) {
        self.statusBarVisibility = statusBarVisibility
        self.toolbarVisibility = toolbarVisibility
        self.tabPickerVisibility = tabPickerVisibility
        self.columnVisibility = initialColumnVisibility
        self.initialTab = initialTab
        self.initialNavigationId = initialNavigationId
    }

    /// 视图主体
    var body: some View {
        ContentView(
            defaultStatusBarVisibility: statusBarVisibility,
            defaultTab: initialTab,
            defaultColumnVisibility: columnVisibility,
            defaultTabVisibility: tabPickerVisibility,
            defaultNavigationId: initialNavigationId
        )
    }
}

// MARK: - Modifier

extension ContentLayout {
    /// 隐藏侧边栏
    /// - Returns: 一个新的 ContentLayout 实例，侧边栏被隐藏
    func hideSidebar() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: .detailOnly,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 显示侧边栏
    /// - Returns: 一个新的 ContentLayout 实例，侧边栏被显示
    func showSidebar() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: .all,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 隐藏状态栏
    /// - Returns: 一个新的 ContentLayout 实例，状态栏被隐藏
    func hideStatusBar() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: false,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 显示状态栏
    /// - Returns: 一个新的 ContentLayout 实例，状态栏被显示
    func showStatusBar() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: true,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 隐藏工具栏
    /// - Returns: 一个新的 ContentLayout 实例，工具栏被隐藏
    func hideToolbar() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: false,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 显示工具栏
    /// - Returns: 一个新的 ContentLayout 实例，工具栏被显示
    func showToolbar() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: true,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 隐藏标签选择器
    /// - Returns: 一个新的 ContentLayout 实例，标签选择器被隐藏
    func hideTabPicker() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: false,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 显示标签选择器
    /// - Returns: 一个新的 ContentLayout 实例，标签选择器被显示
    func showTabPicker() -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: true,
            initialTab: self.initialTab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 设置初始标签页
    /// - Parameter tab: 要设置的初始标签页名称
    /// - Returns: 一个新的 ContentLayout 实例，初始标签页被设置
    func setInitialTab(_ tab: String) -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: tab,
            initialNavigationId: self.initialNavigationId
        )
    }

    /// 设置初始导航
    /// - Parameter id: 要设置的初始导航 ID
    /// - Returns: 一个新的 ContentLayout 实例，初始导航 ID 被设置
    func withNavigation(_ id: String) -> ContentLayout {
        return ContentLayout(
            statusBarVisibility: self.statusBarVisibility,
            initialColumnVisibility: self.columnVisibility,
            toolbarVisibility: self.toolbarVisibility,
            tabPickerVisibility: self.tabPickerVisibility,
            initialTab: self.initialTab,
            initialNavigationId: id
        )
    }
}

// MARK: - Preview

#Preview("Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
