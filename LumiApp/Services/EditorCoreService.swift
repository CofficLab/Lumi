import CodeEditTextView
import EditorMultiCursorCommandsPlugin
import Foundation
import EditorService
import LumiCoreKit
import LumiPluginRegistry
import LumiUI

@MainActor
final class EditorCoreService: LumiEditorServicing {
    private let core: EditorCore
    private let themeRegistry: LumiUIThemeRegistry

    var editorService: EditorService { core.editorService }
    var extensionRegistry: EditorExtensionRegistry { core.extensionRegistry }

    var currentProjectPathProvider: (() -> String)? {
        get { core.currentProjectPathProvider }
        set { core.currentProjectPathProvider = newValue }
    }

    init(
        pluginService: PluginService,
        persistenceRootURL: @escaping @Sendable () -> URL,
        themeRegistry: LumiUIThemeRegistry = .shared,
        recentProjects: @escaping @Sendable () -> [Project] = { [] }
    ) {
        self.themeRegistry = themeRegistry
        let core = EditorCore()
        core.extensionInstaller = { registry in
            await EditorExtensionsBootstrap.registerAll(
                into: registry,
                enabledPluginIDs: pluginService.enabledEditorExtensionPluginIDs
            )
        }
        self.core = core
        EditorLanguageRuntimeBridge.configure = { context in
            await EditorExtensionRuntimeBootstrap.configureRuntime(context)
        }
        configureLifecycle(
            persistenceRootURL: persistenceRootURL,
            recentProjects: recentProjects
        )
        core.reinstallExtensions()
    }

    func reinstallExtensions() {
        core.reinstallExtensions()
    }

    private func configureLifecycle(
        persistenceRootURL: @escaping @Sendable () -> URL,
        recentProjects: @escaping @Sendable () -> [Project]
    ) {
        AppProjectsVM.recentProjectsProvider = recentProjects

        EditorSettingsLifecycle.hostPersistenceRootURL = persistenceRootURL
        EditorSettingsLifecycle.onReinstallPlugins = { [weak self] registry in
            Task { @MainActor in
                await self?.core.extensionInstaller?(registry)
            }
        }
        EditorSettingsLifecycle.editorThemeIDForAppThemeID = { [themeRegistry] _ in
            themeRegistry.resolvedEditorThemeId(colorScheme: .dark) ?? "xcode-dark"
        }
        EditorSettingsLifecycle.registerEditorThemeContributors = { [themeRegistry] registry in
            EditorBuiltinSyntaxThemes.registerAll(into: registry)
            for contribution in themeRegistry.themes {
                if let contributor = contribution.attachments.editorThemeContributor as? any SuperEditorThemeContributor {
                    registry.registerThemeContributor(contributor)
                }
            }
        }
        EditorSettingsLifecycle.registerMultiCursorTextView = { textView, state in
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
        }
    }
}
