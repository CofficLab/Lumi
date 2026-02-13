import SwiftUI

/// 应用程序的主视图组件
/// 提供便捷的初始化方法和修饰符来配置 ContentView 的行为
struct ContentLayout: View {
    /// 应用状态提供者环境对象
    @EnvironmentObject var app: AppProvider

    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    /// 初始选中的导航 ID
    private(set) var initialNavigationId: String?

    /// 初始侧边栏可见性
    private(set) var initialSidebarVisibility: Bool?

    /// 初始化内容布局
    /// - Parameters:
    ///   - initialNavigationId: 初始导航 ID
    ///   - initialSidebarVisibility: 初始侧边栏可见性
    init(
        initialNavigationId: String? = nil,
        initialSidebarVisibility: Bool? = nil
    ) {
        self.initialNavigationId = initialNavigationId
        self.initialSidebarVisibility = initialSidebarVisibility
    }

    /// 视图主体
    var body: some View {
        ContentView(
            defaultNavigationId: initialNavigationId,
            defaultSidebarVisibility: initialSidebarVisibility
        )
    }
}

// MARK: - Modifier

extension ContentLayout {
    /// 隐藏侧边栏
    /// - Returns: 一个新的 ContentLayout 实例，侧边栏被隐藏
    func hideSidebar() -> ContentLayout {
        return ContentLayout(
            initialNavigationId: self.initialNavigationId,
            initialSidebarVisibility: false
        )
    }

    /// 显示侧边栏
    /// - Returns: 一个新的 ContentLayout 实例，侧边栏被显示
    func showSidebar() -> ContentLayout {
        return ContentLayout(
            initialNavigationId: self.initialNavigationId,
            initialSidebarVisibility: true
        )
    }

    /// 设置初始导航
    /// - Parameter id: 要设置的初始导航 ID
    /// - Returns: 一个新的 ContentLayout 实例，初始导航 ID 被设置
    func withNavigation(_ id: String) -> ContentLayout {
        return ContentLayout(
            initialNavigationId: id,
            initialSidebarVisibility: self.initialSidebarVisibility
        )
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
