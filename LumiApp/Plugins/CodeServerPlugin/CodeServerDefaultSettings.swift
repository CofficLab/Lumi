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
        "workbench.activityBar.location": "hidden",
        // 底部状态栏
        "workbench.statusBar.visible": false,
        // 命令中心
        "window.commandCenter": false,
        // 面包屑导航
        "breadcrumbs.enabled": false,
        // 布局控件
        "workbench.layoutControl.enabled": false,
        // 隐藏小地图
        "editor.minimap.enabled": false,
        // 隐藏顶部菜单栏
        "window.menuBarVisibility": "auto",
        // 启动时欢迎页
        "workbench.startupEditor": "none",
        // 侧边栏
        "workbench.sideBar.visible": false,
        // 编辑器标签页
        "workbench.editor.showTabs": "single",
        // 颜色主题
        "workbench.colorTheme": "Default Dark+",
        // 自动更新检查
        "update.mode": "none",
        // 遥测
        "telemetry.telemetryLevel": "off",
        // 图标主题
        "workbench.iconTheme": "material-icon-theme",
        // 标题栏样式
        "window.titleBarStyle": "custom",
    ]
}
