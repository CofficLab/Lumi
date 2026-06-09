import CSSEditorPlugin
import EditorLSPContextCommandsPlugin
import EditorMultiCursorCommandsPlugin
import EditorService
import EditorSwiftKeywordHoverPlugin
import EditorXcodePlugin
import GoEditorPlugin
import HTMLEditorPlugin
import JSEditorPlugin
import LumiCoreKit
import LSPCallHierarchyEditorPlugin
import LSPCodeActionEditorPlugin
import LSPDocumentColorEditorPlugin
import LSPDocumentHighlightEditorPlugin
import LSPDocumentLinkEditorPlugin
import LSPFoldingRangeEditorPlugin
import LSPInlayHintEditorPlugin
import LSPRealtimeSignalsEditorPlugin
import LSPSelectionRangeEditorPlugin
import LSPServiceEditorPlugin
import LSPSheetsEditorPlugin
import LSPSignatureHelpEditorPlugin
import LSPToolbarEditorPlugin
import LSPWorkspaceSymbolEditorPlugin
import MarkdownEditorPlugin
import SwiftPrimitiveTypesEditorPlugin
import SwiftSelectionCodeActionEditorPlugin
import VueEditorPlugin

@MainActor
public enum EditorExtensionsBootstrap {
    public static func registerAll(into registry: EditorExtensionRegistry) async {
        registry.uninstallAll()

        var records: [EditorInstalledPluginRecord] = []

        await EditorXcodePlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: EditorXcodePlugin.self))

        await LSPServiceEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPServiceEditorPlugin.self))

        await LSPRealtimeSignalsEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPRealtimeSignalsEditorPlugin.self))

        await LSPSheetsEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPSheetsEditorPlugin.self))

        await LSPToolbarEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPToolbarEditorPlugin.self))

        await LSPCodeActionEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPCodeActionEditorPlugin.self))

        await LSPCallHierarchyEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPCallHierarchyEditorPlugin.self))

        await LSPWorkspaceSymbolEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPWorkspaceSymbolEditorPlugin.self))

        await LSPDocumentHighlightEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPDocumentHighlightEditorPlugin.self))

        await LSPInlayHintEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPInlayHintEditorPlugin.self))

        await LSPSignatureHelpEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPSignatureHelpEditorPlugin.self))

        await LSPFoldingRangeEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPFoldingRangeEditorPlugin.self))

        await LSPDocumentColorEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPDocumentColorEditorPlugin.self))

        await LSPDocumentLinkEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPDocumentLinkEditorPlugin.self))

        await LSPSelectionRangeEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: LSPSelectionRangeEditorPlugin.self))

        await EditorLSPContextCommandsPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: EditorLSPContextCommandsPlugin.self))

        await EditorMultiCursorCommandsPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: EditorMultiCursorCommandsPlugin.self))

        await VueEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: VueEditorPlugin.self))

        await JSEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: JSEditorPlugin.self))

        await GoEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: GoEditorPlugin.self))

        await HTMLEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: HTMLEditorPlugin.self))

        await CSSEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: CSSEditorPlugin.self))

        await MarkdownEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: MarkdownEditorPlugin.self))

        await SwiftPrimitiveTypesEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: SwiftPrimitiveTypesEditorPlugin.self))

        await SwiftSelectionCodeActionEditorPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: SwiftSelectionCodeActionEditorPlugin.self))

        await EditorSwiftKeywordHoverPlugin.shared.registerEditorExtensions(into: registry)
        records.append(record(for: EditorSwiftKeywordHoverPlugin.self))

        registry.recordInstalledPlugins(records)
    }

    private static func record<P: SuperPlugin>(for _: P.Type) -> EditorInstalledPluginRecord {
        EditorInstalledPluginRecord(
            id: P.id,
            displayName: P.displayName,
            description: P.displayName,
            order: P.order,
            isConfigurable: false
        )
    }
}
