import Foundation

/// LSP 实时信号编辑器插件：触发实时 LSP 更新
actor LSPRealtimeSignalsEditorPlugin: SuperPlugin {
    static let id = "LSPRealtimeSignalsEditor"
    static let displayName = String(localized: "LSP Realtime Signals", table: "LSPRealtimeSignalsEditor")
    static let description = String(localized: "Triggers realtime LSP updates for highlights, hints, and signature help.", table: "LSPRealtimeSignalsEditor")
    static let iconName = "wifi"
    static let order = 18
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerInteractionContributor(LSPRealtimeInteractionContributor())
    }
}
