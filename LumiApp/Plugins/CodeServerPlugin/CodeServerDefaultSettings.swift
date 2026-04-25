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
        // 左侧活动栏
        "workbench.activityBar.visible": true,
        // 底部状态栏
        "workbench.statusBar.visible": true,
        // 面包屑导航
        "breadcrumbs.enabled": true,
        // 隐藏小地图
        "editor.minimap.enabled": false,
        // 隐藏顶部菜单栏
        "window.menuBarVisibility": "auto",
        // 启动时欢迎页
        "workbench.startupEditor": "none",
        // 自动更新检查
        "update.mode": "none",
        // 遥测
        "telemetry.telemetryLevel": "off",
    ]
}
