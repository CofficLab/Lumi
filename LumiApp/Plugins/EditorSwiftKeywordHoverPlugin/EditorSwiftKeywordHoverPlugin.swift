import Foundation

/// Swift 关键字悬浮提示编辑器插件：显示常见 Swift 关键字的文档
actor EditorSwiftKeywordHoverPlugin: SuperPlugin {
    static let id = "EditorSwiftKeywordHover"
    static let displayName = String(localized: "Editor Swift Keyword Hover", table: "EditorSwiftKeywordHover")
    static let description = String(localized: "Shows inline hover documentation for common Swift keywords.", table: "EditorSwiftKeywordHover")
    static let iconName = "swift"
    static let order = 20
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerHoverContributor(EditorSwiftKeywordHoverContributor())
    }
}
