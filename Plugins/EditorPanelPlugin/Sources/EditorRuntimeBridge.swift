import EditorTerminalPlugin
import EditorPreviewPlugin
import EditorService
import EditorStickySymbolBarPlugin
import Foundation
import LumiKernel
import LumiUI

@MainActor
public enum EditorRuntimeBridge {
    public private(set) static var editor: (any LumiEditorServicing)?

    public static var editorService: EditorService? { editor?.editorService }
    public static var extensionRegistry: EditorExtensionRegistry? { editor?.extensionRegistry }

    public static func configure(editor: any LumiEditorServicing) {
        self.editor = editor
        wireBridges()
    }

    public static func wireBridges() {
        guard let editor else { return }
        let service = editor.editorService

        // EditorPreviewBridge
        EditorPreviewRuntimeBridge.editorServiceProvider = { service }

        // EditorStickySymbolBarBridge
        EditorStickySymbolBarBridge.editorServiceProvider = { service }

        // EditorBottomTerminalBridge
        EditorBottomTerminalBridge.editorThemeIdProvider = {
            let scheme = AppThemeAppearanceResolver.effectiveColorScheme
            return LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        }

        // Add to chat handler
        EditorPreviewRuntimeBridge.addToChatHandler = { text in
            NotificationCenter.default.post(
                name: Notification.Name("addToChat"),
                object: nil,
                userInfo: ["text": text, "windowId": service.state.windowId as Any]
            )
        }
    }
}