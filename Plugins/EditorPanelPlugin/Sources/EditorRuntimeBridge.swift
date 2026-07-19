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

        EditorPreviewRuntimeBridge.editorServiceProvider = { _ in service }
        EditorStickySymbolBarBridge.editorServiceProvider = { _ in service }

        EditorBottomTerminalBridge.currentProjectPathProvider = { _ in
            editor.currentProjectPathProvider?() ?? ""
        }
        EditorBottomTerminalBridge.editorThemeIdProvider = {
            let scheme = AppThemeAppearanceResolver.effectiveColorScheme
            return LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        }

        EditorPreviewRuntimeBridge.addToChatHandler = { text, _ in
            NotificationCenter.default.post(
                name: Notification.Name("addToChat"),
                object: nil,
                userInfo: ["text": text, "windowId": service.state.windowId as Any]
            )
        }

        let runtime = PluginRuntimeContext(
            editorServiceProvider: { _ in service },
            currentProjectPath: { _ in editor.currentProjectPathProvider?() }
        )
        runtime.addToChat = { text, _ in
            NotificationCenter.default.post(
                name: Notification.Name("addToChat"),
                object: nil,
                userInfo: ["text": text, "windowId": service.state.windowId as Any]
            )
        }
        runtime.openFile = { url, projectRoot, _ in
            if let projectRoot {
                await service.refreshProjectContext(for: projectRoot)
            }
            service.sessions.open(at: url)
        }

        Task { @MainActor in
            await EditorLanguageRuntimeBridge.configure?(runtime)
        }
    }
}
