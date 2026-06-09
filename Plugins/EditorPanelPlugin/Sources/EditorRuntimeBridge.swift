import EditorBottomCallHierarchyPlugin
import EditorBottomProblemsPlugin
import EditorBottomReferencesPlugin
import EditorBottomSearchPlugin
import EditorBottomSymbolsPlugin
import EditorBottomTerminalPlugin
import EditorBreadcrumbPlugin
import EditorPreviewPlugin
import EditorService
import EditorStickySymbolBarPlugin
import EditorTabStripPlugin
import GoEditorPlugin
import JSEditorPlugin
import Foundation
import LumiCoreKit
import LumiUI

@MainActor
public enum EditorRuntimeBridge {
    public private(set) static var core: EditorCore?

    public static var editorService: EditorService? { core?.editorService }
    public static var extensionRegistry: EditorExtensionRegistry? { core?.extensionRegistry }

    public static func configure(core: EditorCore) {
        self.core = core
        wireBridges()
    }

    public static func wireBridges() {
        guard let core else { return }
        let service = core.editorService

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
            core.currentProjectPathProvider?() ?? ""
        }
        EditorBottomTerminalBridge.editorThemeIdProvider = {
            LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: .dark) ?? "xcode-dark"
        }

        EditorPreviewRuntimeBridge.addToChatHandler = { _, _ in }

        let runtime = PluginRuntimeContext(
            editorServiceProvider: { _ in service },
            currentProjectPath: { _ in core.currentProjectPathProvider?() }
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
