import AppKit
import SwiftUI

/// 插件协议，定义插件的基本接口和UI贡献方法
protocol SuperPlugin: Actor {
    /// 插件唯一标识符
    static var id: String { get }

    /// 插件显示名称
    static var displayName: String { get }

    /// 插件描述
    static var description: String { get }

    /// 插件图标名称
    static var iconName: String { get }

    /// 是否可配置
    static var isConfigurable: Bool { get }

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String { get }

    /// 添加工具栏前导视图
    /// - Returns: 要添加到工具栏前导的视图，如果不需要则返回nil
    @MainActor func addToolBarLeadingView() -> AnyView?

    /// 添加工具栏右侧视图
    /// - Returns: 要添加到工具栏右侧的视图，如果不需要则返回nil
    @MainActor func addToolBarTrailingView() -> AnyView?

    /// 添加详情视图
    /// - Returns: 要添加的详情视图，如果不需要则返回nil
    @MainActor func addDetailView() -> AnyView?

    /// 添加设置视图
    /// - Returns: 要添加的设置视图，如果不需要则返回nil
    @MainActor func addSettingsView() -> AnyView?
    
    /// 提供导航入口（用于侧边栏导航）
    /// - Returns: 导航入口数组，如果不需要则返回nil
    @MainActor func addNavigationEntries() -> [NavigationEntry]?

    /// 添加状态栏弹窗视图
    /// - Returns: 要添加到状态栏弹窗的视图，如果不需要则返回nil
    @MainActor func addStatusBarPopupView() -> AnyView?

    /// 添加状态栏内容视图
    /// - Returns: 要显示在状态栏图标位置的视图，如果不需要则返回nil
    /// - Note: 插件可以提供自定义的状态栏内容视图，内核会将其组合显示
    @MainActor func addStatusBarContentView() -> AnyView?

    // MARK: - Lifecycle Hooks

    /// 插件注册完成后的回调
    nonisolated func onRegister()

    /// 插件被启用时的回调
    nonisolated func onEnable()

    /// 插件被禁用时的回调
    nonisolated func onDisable()

    /// 插件注册顺序（数字越小越先加载）
    static var order: Int { get }
}

// MARK: - Default Implementation

extension SuperPlugin {
    /// 自动派生插件 ID（类名去掉 "Plugin" 后缀）
    static var id: String {
        String(describing: self)
            .replacingOccurrences(of: "Plugin", with: "")
    }
    
    /// 默认实例标签
    nonisolated var instanceLabel: String { Self.id }
    
    /// 默认显示名称
    static var displayName: String { id }
    
    /// 默认描述
    static var description: String { "" }
    
    /// 默认图标
    static var iconName: String { "puzzlepiece" }
    
    /// 默认可配置
    static var isConfigurable: Bool { false }
    
    /// 默认应该注册
    static var shouldRegister: Bool { true }
    
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

    // MARK: - Lifecycle Hooks Default Implementation
    
    /// 默认实现：注册完成后不执行任何操作
    nonisolated func onRegister() {}
    
    /// 默认实现：启用时不执行任何操作
    nonisolated func onEnable() {}
    
    /// 默认实现：禁用时不执行任何操作
    nonisolated func onDisable() {}
    
    // MARK: - Configuration Defaults

    /// 默认注册顺序 (999)
    static var order: Int { 999 }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
