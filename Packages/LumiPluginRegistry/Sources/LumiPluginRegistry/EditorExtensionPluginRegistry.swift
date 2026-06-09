import CSSEditorPlugin
import EditorPanelPlugin
import EditorLSPContextCommandsPlugin
import EditorMultiCursorCommandsPlugin
import EditorSwiftKeywordHoverPlugin
import HTMLEditorPlugin
import LumiCoreKit
import LSPCallHierarchyEditorPlugin
import LSPCodeActionEditorPlugin
import LSPDocumentColorEditorPlugin
import LSPDocumentLinkEditorPlugin
import LSPFoldingRangeEditorPlugin
import LSPInlayHintEditorPlugin
import LSPSelectionRangeEditorPlugin
import LSPSheetsEditorPlugin
import LSPToolbarEditorPlugin
import LSPWorkspaceSymbolEditorPlugin
import MarkdownEditorPlugin
import SwiftPrimitiveTypesEditorPlugin
import SwiftSelectionCodeActionEditorPlugin
import VueEditorPlugin

public enum EditorExtensionPluginRegistry {
    public static let plugins: [any LumiEditorExtensionRegistering.Type] = [
        EditorXcodePlugin.self,
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
        EditorMultiCursorCommandsPlugin.self,
        VueEditorPlugin.self,
        JSEditorPlugin.self,
        GoEditorPlugin.self,
        HTMLEditorPlugin.self,
        CSSEditorPlugin.self,
        MarkdownEditorPlugin.self,
        SwiftPrimitiveTypesEditorPlugin.self,
        SwiftSelectionCodeActionEditorPlugin.self,
        EditorSwiftKeywordHoverPlugin.self,
    ]
}
