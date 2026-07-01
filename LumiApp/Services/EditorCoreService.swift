import EditorTextView
import EditorMultiCursorCommandsPlugin
import Foundation
import EditorService
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SuperLogKit
import os

@MainActor
final class EditorCoreService: LumiEditorServicing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.editor-core")
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = true

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
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 EditorCoreService")
        }

        self.themeRegistry = themeRegistry
        let core = EditorCore()
        core.extensionInstaller = { registry in
            await EditorExtensionsBootstrap.registerAll(
                into: registry,
                enabledPluginIDs: pluginService.enabledEditorExtensionPluginIDs
            )
        }
        self.core = core

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ EditorCore 创建完成")
        }

        EditorLanguageRuntimeBridge.configure = { context in
            await EditorExtensionsBootstrap.configureRuntime(context)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)配置生命周期")
        }
        configureLifecycle(
            persistenceRootURL: persistenceRootURL,
            recentProjects: recentProjects
        )

        core.reinstallExtensions()

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ EditorCoreService 初始化完成")
        }
    }

    func reinstallExtensions() {
        if Self.verbose {
            Self.logger.info("\(Self.t)重新安装扩展")
        }
        core.reinstallExtensions()
    }

    func syncAppSyntaxThemes() {
        if Self.verbose {
            Self.logger.info("\(Self.t)同步编辑器语法主题")
        }
        EditorSettingsLifecycle.registerEditorThemeContributors?(extensionRegistry)
        let scheme = AppThemeAppearanceResolver.effectiveColorScheme
        let themeID = themeRegistry.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        editorService.theme.syncInitialThemeFromExternal(themeID)
    }

    private func configureLifecycle(
        persistenceRootURL: @escaping @Sendable () -> URL,
        recentProjects: @escaping @Sendable () -> [Project]
    ) {
        AppProjectsVM.recentProjectsProvider = recentProjects

        EditorSettingsLifecycle.hostPersistenceRootURL = persistenceRootURL
        EditorSettingsLifecycle.onReinstallPlugins = { [weak self] registry in
            Task { @MainActor in
                guard let self else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)重新安装插件扩展")
                }
                await self.core.extensionInstaller?(registry)
                self.core.editorService.state.refreshExtensionProviders()
            }
        }
        EditorSettingsLifecycle.editorThemeIDForAppThemeID = { [themeRegistry] _ in
            let scheme = AppThemeAppearanceResolver.effectiveColorScheme
            return themeRegistry.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        }
        EditorSettingsLifecycle.registerEditorThemeContributors = { [themeRegistry] registry in
            EditorBuiltinSyntaxThemes.registerFallbacks(into: registry)
            AppEditorSyntaxThemeRegistrar.sync(
                contributions: themeRegistry.themes,
                into: registry
            )
        }
        EditorSettingsLifecycle.registerMultiCursorTextView = { textView, state in
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 生命周期配置完成")
        }
    }
}
