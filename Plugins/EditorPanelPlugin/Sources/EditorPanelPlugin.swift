import AgentToolKit
import EditorMultiCursorCommandsPlugin
import EditorService
import EditorTabStripPlugin
import EditorXcodePlugin
import LSPServiceEditorPlugin
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// Unified code editor plugin for the Lumi activity bar.
public enum EditorPanelPlugin: LumiPlugin {
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")
    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "LumiEditor",
        displayName: String(localized: "Code Editor", bundle: .module),
        description: String(
            localized: "Code editor with file tree, LSP, and workspace panels.",
            bundle: .module
        ),
        order: 77
    )

    @MainActor
    private static var sharedCore: EditorCore?

    @MainActor
    public static func bootstrap(
        persistenceRootURL: @escaping @Sendable () -> URL,
        themeRegistry: LumiUIThemeRegistry = .shared,
        recentProjects: @escaping @Sendable () -> [Project] = { [] }
    ) {
        let core = EditorCore()
        sharedCore = core

        AppProjectsVM.recentProjectsProvider = recentProjects

        EditorSettingsLifecycle.hostPersistenceRootURL = persistenceRootURL
        EditorSettingsLifecycle.onReinstallPlugins = { registry in
            Task {
                await EditorExtensionsBootstrap.registerAll(into: registry)
            }
        }
        EditorSettingsLifecycle.editorThemeIDForAppThemeID = { _ in
            themeRegistry.resolvedEditorThemeId(colorScheme: .dark) ?? "xcode-dark"
        }
        EditorSettingsLifecycle.registerEditorThemeContributors = { registry in
            registerSyntaxThemes(from: themeRegistry, into: registry)
        }
        EditorSettingsLifecycle.registerMultiCursorTextView = { textView, state in
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
        }

        core.reinstallExtensions()
        EditorRuntimeBridge.configure(core: core)
    }

    @MainActor
    public static func sharedEditorCore() -> EditorCore? {
        sharedCore
    }

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        guard
            let projectPathStore = context.resolve(LumiCurrentProjectPathStoring.self) as? LumiCurrentProjectPathStore,
            let core = sharedCore
        else {
            return []
        }

        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                EditorPanelHostView(projectPathStore: projectPathStore, editorCore: core)
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            GetCurrentFileTool().asLumiAgentTool(),
            SetCurrentFileTool().asLumiAgentTool(),
            AddSwiftPackageTool().asLumiAgentTool(),
            ListSwiftPackagesTool().asLumiAgentTool(),
            GenerateXcodeProjectTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == info.id, let service = EditorRuntimeBridge.editorService else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).lsp",
                title: "LSP",
                systemImage: "waveform.path.ecg",
                placement: .trailing,
                statusBarView: {
                    LSPDiagnosticStatusBarItem()
                }
            ),
            LumiStatusBarItem(
                id: "\(info.id).cursor",
                title: "Cursor",
                systemImage: "cursorarrow",
                placement: .trailing,
                statusBarView: {
                    EditorCursorStatusBarView(service: service)
                }
            ),
        ]
    }

    @MainActor
    private static func registerSyntaxThemes(
        from themeRegistry: LumiUIThemeRegistry,
        into registry: EditorExtensionRegistry
    ) {
        EditorBuiltinSyntaxThemes.registerAll(into: registry)
        for contribution in themeRegistry.themes {
            if let contributor = contribution.attachments.editorThemeContributor as? any SuperEditorThemeContributor {
                registry.registerThemeContributor(contributor)
            }
        }
    }
}

private struct EditorCursorStatusBarView: View {
    @ObservedObject var service: EditorService

    var body: some View {
        Text("Ln \(service.cursorLine + 1), Col \(service.cursorColumn + 1)")
            .font(.caption)
            .monospacedDigit()
    }
}
