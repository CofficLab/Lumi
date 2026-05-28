import Foundation

/// Swift 关键字悬浮提示编辑器插件：显示常见 Swift 关键字的文档
actor EditorSwiftKeywordHoverPlugin: SuperPlugin {
    static let shared = EditorSwiftKeywordHoverPlugin()
    static let id = "EditorSwiftKeywordHover"
    static let displayName = String(localized: "Editor Swift Keyword Hover", table: "EditorSwiftKeywordHover")
    static let description = String(localized: "Shows inline hover documentation for common Swift keywords.", table: "EditorSwiftKeywordHover")
    static let iconName = "swift"
    static let order = 20
    static var category: PluginCategory { .general }
    nonisolated static let policy: PluginPolicy = .disabled

    /// 插件注册策略：开发中，暂不注册

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerHoverContributor(EditorSwiftKeywordHoverContributor())
    }
}
