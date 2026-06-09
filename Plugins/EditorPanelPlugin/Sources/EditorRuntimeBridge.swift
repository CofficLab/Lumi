import EditorService
import Foundation
import LumiCoreKit
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

        EditorTabStripBridge.editorServiceProvider = { _ in service }
        BreadcrumbNavBridge.editorServiceProvider = { _ in service }
        EditorBottomProblemsBridge.editorServiceProvider = { _ in service }
        EditorBottomReferencesBridge.editorServiceProvider = { _ in service }
        EditorBottomSymbolsBridge.editorServiceProvider = { _ in service }
        EditorBottomSearchBridge.editorServiceProvider = { _ in service }
        EditorBottomCallHierarchyBridge.editorServiceProvider = { _ in service }
        EditorPreviewRuntimeBridge.editorServiceProvider = { _ in service }
        EditorStickySymbolBarBridge.editorServiceProvider = { _ in service }

        EditorBottomTerminalBridge.currentProjectPathProvider = { _ in
            editor.currentProjectPathProvider?() ?? ""
        }
        EditorBottomTerminalBridge.editorThemeIdProvider = {
            LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: .dark) ?? "xcode-dark"
        }

        EditorPreviewRuntimeBridge.addToChatHandler = { _, _ in }

        let runtime = PluginRuntimeContext(
            editorServiceProvider: { _ in service },
            currentProjectPath: { _ in editor.currentProjectPathProvider?() }
        )
        runtime.openFile = { url, projectRoot, _ in
            if let projectRoot {
                await service.refreshProjectContext(for: projectRoot)
            }
            service.open(at: url)
        }

        Task { @MainActor in
            await GoEditorPlugin.shared.configureRuntime(context: runtime)
            await JSEditorPlugin.shared.configureRuntime(context: runtime)
            await EditorPreviewPlugin.shared.configureRuntime(context: runtime)
        }
    }
}
