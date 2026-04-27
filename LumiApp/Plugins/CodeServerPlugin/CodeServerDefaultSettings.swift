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
        // 左侧活动栏（可选值："default", "top", "hidden"）
        "workbench.activityBar.location": "hidden",
        // 底部状态栏（可选值：true, false）
        "workbench.statusBar.visible": false,
        // 命令中心（可选值：true, false）
        "window.commandCenter": false,
        // 面包屑导航（可选值：true, false）
        "breadcrumbs.enabled": false,
        // 布局控件（可选值：true, false）
        "workbench.layoutControl.enabled": false,
        // 隐藏小地图（可选值：true, false）
        "editor.minimap.enabled": false,
        // 隐藏顶部菜单栏（可选值："classic", "visible", "toggle", "compact", "hidden", "auto"）
        "window.menuBarVisibility": "hidden",
        // 启动时欢迎页（可选值："none", "welcomePage", "readme", "newUntitledFile", "terminal", "welcomePageInEmptyWorkbench"）
        "workbench.startupEditor": "none",
        // 侧边栏（可选值：true, false）
        "workbench.sideBar.visible": false,
        // 辅助侧边栏默认隐藏（可选值："default", "hidden"）
        "workbench.secondarySideBar.defaultVisibility": "hidden",
        // 编辑器标签页（可选值："multiple", "single", "none"）
        "workbench.editor.showTabs": "single",
        // 自动更新检查（可选值："none", "manual", "start", "default"）
        "update.mode": "none",
        // 遥测（可选值："all", "error", "crash", "off"）
        "telemetry.telemetryLevel": "off",
        // 标题栏样式（可选值："native", "custom"）
        "window.titleBarStyle": "custom",
    ]
}
