import Foundation

/// Swift 选区代码动作编辑器插件：提供基于选区的 Swift 代码动作
actor SwiftSelectionCodeActionEditorPlugin: SuperPlugin {
    static let id = "SwiftSelectionCodeActionEditor"
    static let displayName = String(localized: "Swift Selection Code Actions", table: "SwiftSelectionCodeActionEditor")
    static let description = String(localized: "Provides selection-based Swift code actions.", table: "SwiftSelectionCodeActionEditor")
    static let iconName = "cursorarrow.click.badge.clock"
    static let order = 30
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCodeActionContributor(SwiftSelectionCodeActionContributor())
    }
}
