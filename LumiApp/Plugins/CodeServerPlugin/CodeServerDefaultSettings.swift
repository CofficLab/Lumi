import Foundation

/// code-server 默认写入 settings.json 的配置项
///
/// 用于隐藏不必要的 UI 元素，提供沉浸式编辑体验。
enum CodeServerDefaultSettings {
    
    /// 默认配置字典
    ///
    /// 使用 `nonisolated(unsafe)` 标记为并发安全。
    /// 因为该属性是 `let` 常量（不可变），在初始化后不存在数据竞争，
    /// 因此在多个 Actor 间共享是安全的，尽管其类型 `[String: Any]` 不是 `Sendable`。
    nonisolated(unsafe) static let values: [String: Any] = [
        // 隐藏左侧活动栏
        "workbench.activityBar.visible": true,
        // 隐藏底部状态栏
        "workbench.statusBar.visible": false,
        // 隐藏面包屑导航
        "breadcrumbs.enabled": false,
        // 隐藏小地图
        "editor.minimap.enabled": false,
        // 隐藏顶部菜单栏
        "window.menuBarVisibility": "hidden",
        // 启动时不显示欢迎页
        "workbench.startupEditor": "none",
        // 关闭自动更新检查
        "update.mode": "none",
        // 关闭遥测
        "telemetry.telemetryLevel": "off",
        // 使用浅色标题栏（可选，与 Lumi 风格匹配）
        "window.titleBarStyle": "custom",
    ]
}
