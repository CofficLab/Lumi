import CodeEditTextView
import Foundation

/// 由宿主（LumiApp）注入：在插件启用状态变化时重新向 `EditorExtensionRegistry` 注册扩展。
public enum EditorSettingsLifecycle {
    public nonisolated(unsafe) static var onReinstallPlugins: ((EditorExtensionRegistry) -> Void)?
    /// Quick Open 选中「跳转编辑器设置」项时由宿主处理（打开设置页并填入搜索词）。
    public nonisolated(unsafe) static var onQuickOpenSettingSelected: ((String) -> Void)?

    /// 与 `AppConfig.getDBFolderURL()`（或等价路径）一致，供 `EditorKeybindingStore` 等落盘。
    public nonisolated(unsafe) static var hostPersistenceRootURL: (() -> URL)?

    /// 当主题通知仅有 `themeId`、缺少 `editorThemeId` 时，将 App 主题 ID 解析为编辑器主题 ID。
    public nonisolated(unsafe) static var editorThemeIDForAppThemeID: ((String) -> String)?

    public nonisolated(unsafe) static var loadEditorRecentCommandIDs: (() -> [String])?
    public nonisolated(unsafe) static var saveEditorRecentCommandIDs: (([String]) -> Void)?
    public nonisolated(unsafe) static var loadEditorCommandUsageCounts: (() -> [String: Int])?
    public nonisolated(unsafe) static var saveEditorCommandUsageCounts: (([String: Int]) -> Void)?
    public nonisolated(unsafe) static var loadEditorCommandPaletteCategory: (() -> String?)?
    public nonisolated(unsafe) static var saveEditorCommandPaletteCategory: ((String?) -> Void)?

    /// 切换「编辑器功能插件」开关（宿主通常映射到 `AppPluginSettingsVM`）。
    public nonisolated(unsafe) static var setEditorFeaturePluginEnabled: ((String, Bool) -> Void)?

    /// 将宿主主题贡献中的 `editorThemeContributor` 注册到编辑器 registry。
    public nonisolated(unsafe) static var registerEditorThemeContributors: ((EditorExtensionRegistry) -> Void)?

    /// 宿主注册多光标输入 swizzle（Lumi 中通常为 `MultiCursorInputInstaller`）。
    public nonisolated(unsafe) static var registerMultiCursorTextView: ((TextView, EditorState) -> Void)?
}
