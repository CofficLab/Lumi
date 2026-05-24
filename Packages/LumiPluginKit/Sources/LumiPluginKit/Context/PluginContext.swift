import Foundation

/// 插件视图构建上下文
///
/// 在插件构建视图时提供的上下文，承载当前 UI 状态信息。
/// PluginKit 中定义最小化版本，内核在运行时注入完整实现。
///
/// ## 扩展指南
///
/// 当需要向插件传递更多上下文信息时，在此结构体中添加新属性即可。
/// 所有新增属性应提供合理的默认值，以保持向后兼容性。
@MainActor
public struct PluginContext {
    /// 当前激活的活动栏图标（SF Symbol 名称）
    ///
    /// 插件可以通过比较此值与自己的面板图标来决定是否提供视图。
    public let activeIcon: String?

    /// 编辑器是否可见
    ///
    /// 当编辑器未显示时（如纯 Agent 模式），依赖编辑器的插件可据此隐藏自身视图。
    public let isEditorVisible: Bool

    public init(
        activeIcon: String? = nil,
        isEditorVisible: Bool = true
    ) {
        self.activeIcon = activeIcon
        self.isEditorVisible = isEditorVisible
    }
}
