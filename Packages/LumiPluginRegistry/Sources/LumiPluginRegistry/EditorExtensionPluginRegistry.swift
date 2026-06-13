import EditorChatIntegrationPlugin
import EditorCSSPlugin
import EditorGoPlugin
import EditorHTMLPlugin
import EditorJSPlugin
import EditorMarkdownPlugin
import EditorXcodePlugin
import EditorLSPContextCommandsPlugin
import EditorMultiCursorCommandsPlugin
import EditorSwiftKeywordHoverPlugin
import EditorSwiftPrimitiveTypesPlugin
import EditorSwiftSelectionCodeActionPlugin
import EditorVuePlugin
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

public enum EditorExtensionPluginRegistry {
    public static let plugins: [any LumiEditorExtensionRegistering.Type] = [
        EditorXcodeEditorPlugin.self,
        LSPServiceEditorPlugin.self,
        LSPRealtimeSignalsEditorPlugin.self,
        LSPSheetsEditorPlugin.self,
        LSPToolbarEditorPlugin.self,
        LSPCodeActionEditorPlugin.self,
        LSPCallHierarchyEditorPlugin.self,
        LSPWorkspaceSymbolEditorPlugin.self,
        LSPDocumentHighlightEditorPlugin.self,
        LSPInlayHintEditorPlugin.self,
        LSPSignatureHelpEditorPlugin.self,
        LSPFoldingRangeEditorPlugin.self,
        LSPDocumentColorEditorPlugin.self,
        LSPDocumentLinkEditorPlugin.self,
        LSPSelectionRangeEditorPlugin.self,
        EditorLSPContextCommandsPlugin.self,
        EditorChatIntegrationPlugin.self,
        EditorMultiCursorCommandsPlugin.self,
        EditorVuePlugin.self,
        EditorJSPlugin.self,
        EditorGoPlugin.self,
        EditorHTMLPlugin.self,
        EditorCSSPlugin.self,
        EditorMarkdownPlugin.self,
        EditorSwiftPrimitiveTypesPlugin.self,
        EditorSwiftSelectionCodeActionPlugin.self,
        EditorSwiftKeywordHoverPlugin.self,
    ]
}
