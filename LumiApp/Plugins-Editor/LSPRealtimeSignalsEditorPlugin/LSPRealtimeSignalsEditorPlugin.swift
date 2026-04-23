import Foundation

@objc(LumiLSPRealtimeSignalsEditorPlugin)
@MainActor
final class LSPRealtimeSignalsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.realtime-signals"
    let displayName: String = String(localized: "LSP Realtime Signals", table: "LSPRealtimeSignalsEditor")
    override var description: String { String(localized: "Triggers realtime LSP updates for highlights, hints, and signature help.", table: "LSPRealtimeSignalsEditor") }
    let order: Int = 18

    func register(into registry: EditorExtensionRegistry) {
        registry.registerInteractionContributor(LSPRealtimeInteractionContributor())
    }
}
