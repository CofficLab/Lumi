import Foundation

// MARK: - Lifecycle Hooks

extension SuperPlugin {
    /// 插件注册完成后的回调
    ///
    /// 当插件被自动发现并注册到系统后调用。
    /// 此时插件已准备好，但可能尚未显示在 UI 中。
    /// 适合执行：
    /// - 初始化插件状态
    /// - 加载持久化配置
    /// - 注册通知观察者
    nonisolated func onRegister()

    /// 插件被启用时的回调
    ///
    /// 当插件从禁用状态变为启用状态时调用。
    /// 此时插件将开始参与 UI 渲染和交互。
    /// 适合执行：
    /// - 启动后台任务
    /// - 连接外部服务
    /// - 更新 UI 状态
    nonisolated func onEnable()

    /// 插件被禁用时的回调
    ///
    /// 当插件从启用状态变为禁用状态时调用。
    /// 此时插件将停止参与 UI 渲染和交互。
    /// 适合执行：
    /// - 停止后台任务
    /// - 断开外部连接
    /// - 保存状态
    nonisolated func onDisable()

    /// 插件注册顺序（数字越小越先加载）
    ///
    /// 决定插件在列表中的排序位置。
    /// 数字越小，优先级越高，越早被加载和处理。
    /// 建议：
    /// - 0-99: 系统核心插件
    /// - 100-499: 主要功能插件
    /// - 500-999: 辅助功能插件
    static var order: Int { get }
}

// MARK: - Lifecycle Default Implementation

extension SuperPlugin {
    /// 默认实现：注册完成后不执行任何操作
    nonisolated func onRegister() {}

    /// 默认实现：启用时不执行任何操作
    nonisolated func onEnable() {}

    /// 默认实现：禁用时不执行任何操作
    nonisolated func onDisable() {}

    /// 默认注册顺序 (999)
    ///
    /// 较高的默认值确保核心插件优先加载。
    static var order: Int { 999 }
}
