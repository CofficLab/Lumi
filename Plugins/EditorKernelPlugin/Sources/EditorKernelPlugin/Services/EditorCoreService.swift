import EditorService
import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import os

/// Bridge between LumiKernel and the EditorService subsystem.
///
/// Manages EditorCore lifecycle, subscribes to plugin enable/disable changes,
/// and syncs app syntax themes to the editor.
@MainActor
final class EditorCoreService: LumiEditorServicing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.editor-core")
    nonisolated static let emoji = "\u{1F4DD}"
    nonisolated static let verbose = false

    private let core: EditorCore
    private let themeRegistry: LumiUIThemeRegistry
    /// Injected by `LumiFactory` after `LumiCore` is available.
    private var lumiCore: LumiCoreAccessing?
    /// Stores the observer token.
    private var pluginsChangedObserver: NSObjectProtocol?

    var editorService: EditorService { core.editorService }
    var extensionRegistry: EditorExtensionRegistry { core.extensionRegistry }

    var currentProjectPathProvider: (() -> String)? {
        get { core.currentProjectPathProvider }
        set { core.currentProjectPathProvider = newValue }
    }

    /// Called by `LumiFactory` after `LumiCore` is available.
    /// Switches `EditorSettingsLifecycle.hostPersistenceRootURL` to
    /// `lumiCore.storage.dataRootDirectory`.
    func configure(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
        EditorSettingsLifecycle.hostPersistenceRootURL = { [weak lumiCore] in
            lumiCore?.storage.dataRootDirectory ?? Self.fallbackPersistenceRootURL
        }
    }

    private static var fallbackPersistenceRootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    init(
        pluginService: PluginRegistry,
        themeRegistry: LumiUIThemeRegistry = .shared
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Initializing EditorCoreService")
        }

        self.themeRegistry = themeRegistry
        let core = EditorCore()
        core.extensionInstaller = { [weak pluginService] registry in
            guard let pluginService else { return }
            await Self.registerEditorExtensions(
                into: registry,
                pluginService: pluginService
            )
        }
        self.core = core

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorCore created")
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)Configuring lifecycle")
        }
        configureLifecycle()

        core.reinstallExtensions()

        // Subscribe to system appearance changes: sync editor syntax themes on appearance switch.
        themeRegistry.onSystemAppearanceDidChange = { [weak self] in
            self?.syncAppSyntaxThemes()
        }

        // Subscribe to plugin enable/disable changes: reinstall editor extensions when plugins change.
        pluginsChangedObserver = NotificationCenter.default.addObserver(
            forName: .lumiEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reinstallExtensions()
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorCoreService initialized")
        }
    }

    // MARK: - Editor Extensions Registration

    private static func registerEditorExtensions(
        into registry: EditorExtensionRegistry,
        pluginService: PluginRegistry
    ) async {
        registry.uninstallAll()

        // In the new architecture, editor extensions are registered through
        // LumiPlugin.registerEditorExtensions(kernel:) during plugin boot.
    }

    // MARK: - Public Methods

    func reinstallExtensions() {
        if Self.verbose {
            Self.logger.info("\(Self.t)Reinstalling extensions")
        }
        core.reinstallExtensions()
    }

    func syncAppSyntaxThemes() {
        if Self.verbose {
            Self.logger.info("\(Self.t)Syncing app syntax themes")
        }
        EditorSettingsLifecycle.registerEditorThemeContributors?(extensionRegistry)
        let scheme = SystemAppearanceResolver.effectiveColorScheme
        let themeID = themeRegistry.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        core.editorService.theme.syncInitialThemeFromExternal(themeID)
    }

    private func configureLifecycle() {
        EditorSettingsLifecycle.onReinstallPlugins = { [weak self] registry in
            Task { @MainActor in
                guard let self else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)Reinstalling plugin extensions")
                }
                await self.core.extensionInstaller?(registry)
                self.core.editorService.state.refreshExtensionProviders()
            }
        }
        EditorSettingsLifecycle.editorThemeIDForAppThemeID = { [themeRegistry] _ in
            let scheme = SystemAppearanceResolver.effectiveColorScheme
            return themeRegistry.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        }
        EditorSettingsLifecycle.registerEditorThemeContributors = { registry in
            EditorBuiltinSyntaxThemes.registerFallbacks(into: registry)
            EditorBuiltinSyntaxThemes.registerAppThemes([], into: registry)
        }
        EditorSettingsLifecycle.registerMultiCursorTextView = { _, _ in
            // Multi-cursor input plugin is deprecated for now.
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)Lifecycle configured")
        }
    }
}
