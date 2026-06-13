import EditorSwiftPlugin
import LSPServiceEditorPlugin
import LSPRealtimeSignalsEditorPlugin
import LSPSheetsEditorPlugin
import LSPToolbarEditorPlugin
import LSPCodeActionEditorPlugin
import LSPCallHierarchyEditorPlugin
import LSPWorkspaceSymbolEditorPlugin
import LSPDocumentHighlightEditorPlugin
import LSPInlayHintEditorPlugin
import LSPSignatureHelpEditorPlugin
import LSPFoldingRangeEditorPlugin
import LSPDocumentColorEditorPlugin
import LSPDocumentLinkEditorPlugin
import LSPSelectionRangeEditorPlugin
import EditorLSPContextCommandsPlugin
import EditorChatIntegrationPlugin
import EditorMultiCursorCommandsPlugin
import EditorVuePlugin
import EditorJSPlugin
import EditorGoPlugin
import EditorHTMLPlugin
import EditorCSSPlugin
import EditorMarkdownPlugin
import EditorAgdaPlugin
import EditorBashPlugin
import EditorCPlugin
import EditorCSharpPlugin
import EditorDartPlugin
import EditorDockerfilePlugin
import EditorElixirPlugin
import EditorHaskellPlugin
import EditorJSONPlugin
import EditorJavaPlugin
import EditorJuliaPlugin
import EditorKotlinPlugin
import EditorLuaPlugin
import EditorOCamlPlugin
import EditorPHPPlugin
import EditorPerlPlugin
import EditorPythonPlugin
import EditorRegexPlugin
import EditorRubyPlugin
import EditorRustPlugin
import EditorSQLPlugin
import EditorScalaPlugin
import EditorTOMLPlugin
import EditorVerilogPlugin
import EditorYAMLPlugin
import EditorZigPlugin
import LumiCoreKit

public enum EditorExtensionPluginRegistry {
    public static let plugins: [any LumiEditorExtensionRegistering.Type] = [
        EditorSwiftEditorPlugin.self,
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
        EditorAgdaPlugin.self,
        EditorBashPlugin.self,
        EditorCPlugin.self,
        EditorCSharpPlugin.self,
        EditorDartPlugin.self,
        EditorDockerfilePlugin.self,
        EditorElixirPlugin.self,
        EditorHaskellPlugin.self,
        EditorJSONPlugin.self,
        EditorJavaPlugin.self,
        EditorJuliaPlugin.self,
        EditorKotlinPlugin.self,
        EditorLuaPlugin.self,
        EditorOCamlPlugin.self,
        EditorPHPPlugin.self,
        EditorPerlPlugin.self,
        EditorPythonPlugin.self,
        EditorRegexPlugin.self,
        EditorRubyPlugin.self,
        EditorRustPlugin.self,
        EditorSQLPlugin.self,
        EditorScalaPlugin.self,
        EditorTOMLPlugin.self,
        EditorVerilogPlugin.self,
        EditorYAMLPlugin.self,
        EditorZigPlugin.self,
    ]
}
