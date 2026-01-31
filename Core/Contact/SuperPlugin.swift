import AppKit
import SwiftUI

/// 插件协议，定义插件的基本接口和UI贡献方法
protocol SuperPlugin {
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
    var instanceLabel: String { get }

    /// 添加工具栏前导视图
    /// - Returns: 要添加到工具栏前导的视图，如果不需要则返回nil
    func addToolBarLeadingView() -> AnyView?

    /// 添加工具栏右侧视图
    /// - Returns: 要添加到工具栏右侧的视图，如果不需要则返回nil
    func addToolBarTrailingView() -> AnyView?

    /// 添加状态栏左侧视图
    /// - Returns: 要添加到状态栏左侧的视图，如果不需要则返回nil
    func addStatusBarLeadingView() -> AnyView?

    /// 添加状态栏右侧视图
    /// - Returns: 要添加到状态栏右侧的视图，如果不需要则返回nil
    func addStatusBarTrailingView() -> AnyView?

    /// 添加详情视图
    /// - Returns: 要添加的详情视图，如果不需要则返回nil
    func addDetailView() -> AnyView?

    /// 添加列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 要添加的列表视图，如果不需要则返回nil
    func addListView(tab: String, project: Project?) -> AnyView?

    /// 添加侧边栏视图
    /// - Returns: 要添加到侧边栏的视图，如果不需要则返回nil
    func addSidebarView() -> AnyView?

    /// 添加系统菜单栏菜单项
    /// - Returns: 要添加到系统菜单栏的菜单项数组，如果不需要则返回nil
    func addStatusBarMenuItems() -> [NSMenuItem]?
    
    // MARK: - Lifecycle Hooks
    
    /// 插件注册完成后的回调
    func onRegister()
    
    /// 插件被启用时的回调
    func onEnable()
    
    /// 插件被禁用时的回调
    func onDisable()
}

// MARK: - Default Implementation

extension SuperPlugin {
    /// 自动派生插件 ID（类名去掉 "Plugin" 后缀）
    static var id: String {
        String(describing: self)
            .replacingOccurrences(of: "Plugin", with: "")
    }
    
    /// 默认实例标签
    var instanceLabel: String { Self.id }
    
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
    func addToolBarLeadingView() -> AnyView? { nil }
    
    /// 默认实现：不提供工具栏右侧视图
    func addToolBarTrailingView() -> AnyView? { nil }
    
    /// 默认实现：不提供状态栏左侧视图
    func addStatusBarLeadingView() -> AnyView? { nil }
    
    /// 默认实现：不提供状态栏右侧视图
    func addStatusBarTrailingView() -> AnyView? { nil }
    
    /// 默认实现：不提供详情视图
    func addDetailView() -> AnyView? { nil }
    
    /// 默认实现：不提供列表视图
    func addListView(tab: String, project: Project?) -> AnyView? { nil }
    
    /// 默认实现：不提供侧边栏视图
    func addSidebarView() -> AnyView? { nil }
    
    /// 默认实现：不提供菜单项
    func addStatusBarMenuItems() -> [NSMenuItem]? { nil }
    
    // MARK: - Lifecycle Hooks Default Implementation
    
    /// 默认实现：注册完成后不执行任何操作
    func onRegister() {}
    
    /// 默认实现：启用时不执行任何操作
    func onEnable() {}
    
    /// 默认实现：禁用时不执行任何操作
    func onDisable() {}
}

/// 项目模型的占位符（需要根据实际需求定义）
struct Project {
    let id: String
    let name: String
    // 其他项目属性...
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
