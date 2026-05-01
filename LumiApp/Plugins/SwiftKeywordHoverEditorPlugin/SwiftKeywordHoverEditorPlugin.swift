import Foundation

/// Swift 关键字悬浮提示编辑器插件：显示常见 Swift 关键字的文档
actor SwiftKeywordHoverEditorPlugin: SuperPlugin {
    static let id = "SwiftKeywordHoverEditor"
    static let displayName = String(localized: "Swift Keyword Hover", table: "SwiftKeywordHoverEditor")
    static let description = String(localized: "Shows inline hover documentation for common Swift keywords.", table: "SwiftKeywordHoverEditor")
    static let iconName = "swift"
    static let order = 20
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerHoverContributor(SwiftKeywordHoverContributor())
    }
}
