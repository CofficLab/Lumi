import Foundation

/// LSP 表格编辑器插件：展示工作区符号和调用层级等 sheet
actor LSPSheetsEditorPlugin: SuperPlugin {
    static let id = "LSPSheetsEditor"
    static let displayName = String(localized: "LSP Sheets", table: "LSPSheetsEditor")
    static let description = String(localized: "Presents LSP sheets such as workspace symbols and call hierarchy.", table: "LSPSheetsEditor")
    static let iconName = "square.on.square"
    static let order = 17
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerSheetContributor(LSPSheetContributor())
    }
}
