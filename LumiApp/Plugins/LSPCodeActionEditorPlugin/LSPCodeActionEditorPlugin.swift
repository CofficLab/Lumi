import Foundation

/// LSP 代码动作编辑器插件：提供快速修复和灯泡建议
actor LSPCodeActionEditorPlugin: SuperPlugin {
    static let id = "LSPCodeActionEditor"
    static let displayName = String(localized: "LSP Code Actions", table: "LSPCodeActionEditor")
    static let description = String(localized: "Provides quick-fix code actions and lightbulb suggestions for diagnostics.", table: "LSPCodeActionEditor")
    static let iconName = "lightbulb"
    static let order = 20
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Code actions are provided via CodeActionProvider (injected into EditorState)
        // This plugin serves as the registration entrypoint for the feature.
    }
}
