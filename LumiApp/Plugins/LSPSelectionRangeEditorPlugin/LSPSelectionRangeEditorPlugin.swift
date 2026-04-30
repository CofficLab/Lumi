import Foundation

/// LSP 选区范围编辑器插件：提供智能扩展/收缩选区
actor LSPSelectionRangeEditorPlugin: SuperPlugin {
    static let id = "LSPSelectionRangeEditor"
    static let displayName = String(localized: "LSP Selection Ranges", table: "LSPSelectionRangeEditor")
    static let description = String(localized: "Provides smart expand/shrink selection via LSP selection ranges.", table: "LSPSelectionRangeEditor")
    static let iconName = "rectangle.on.rectangle"
    static let order = 27
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via SelectionRangeProvider
    }
}
