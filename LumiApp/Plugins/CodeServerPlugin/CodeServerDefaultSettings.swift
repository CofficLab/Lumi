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
        // 兼容旧版键：隐藏活动栏
        "workbench.activityBar.visible": false,
        // 底部状态栏（可选值：true, false）
        "workbench.statusBar.visible": false,
        // 命令中心（可选值：true, false）
        "window.commandCenter": false,
        // 兼容新版键：命令中心
        "workbench.commandCenter": false,
        // 关闭并隐藏内建 AI 功能（Chat / Inline Suggestions / Copilot 扩展入口）
        "chat.disableAIFeatures": true,
        // 隐藏标题栏 Chat 菜单
        "chat.commandCenter.enabled": false,
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
        "workbench.sideBar.visible": true,
        // 辅助侧边栏默认隐藏（可选值："default", "hidden"）
        "workbench.secondarySideBar.defaultVisibility": "hidden",
        // 编辑器标签页（可选值："multiple", "single", "none"）
        "workbench.editor.showTabs": "none",
        // 隐藏编辑器右上角操作区（更多菜单/布局按钮）
        "workbench.editor.editorActionsLocation": "hidden",
        // 关闭编辑器居中布局，避免左右大留白
        "workbench.editor.centeredLayout": false,
        // 关闭居中布局的自适应与固定宽度，避免编辑区出现左右大留白
        "workbench.editor.centeredLayoutAutoResize": false,
        "workbench.editor.centeredLayoutFixedWidth": false,
        // 关闭 Zen Mode 的居中布局联动
        "zenMode.centerLayout": false,
        // 自动更新检查（可选值："none", "manual", "start", "default"）
        "update.mode": "none",
        // 遥测（可选值："all", "error", "crash", "off"）
        "telemetry.telemetryLevel": "off",
        // 标题栏样式（可选值："native", "custom"）
        "window.titleBarStyle": "custom",
        // 关闭 Workspace Trust，首次打开项目不再弹信任确认框
        "security.workspace.trust.enabled": false,
        // 未受信文件直接打开，不再弹出提示（可选值："prompt", "open", "newWindow"）
        "security.workspace.trust.untrustedFiles": "open",
        // 启动时不显示 trust 提示（可选值："always", "once", "never"）
        "security.workspace.trust.startupPrompt": "never",
        // 不显示 trust 横幅（可选值："always", "untilDismissed", "never"）
        "security.workspace.trust.banner": "never",
        // 禁用扩展推荐，避免首次打开项目弹出“安装推荐扩展”
        "extensions.ignoreRecommendations": true,
        // 仅在用户主动触发时显示推荐
        "extensions.showRecommendationsOnlyOnDemand": true,
    ]
}
