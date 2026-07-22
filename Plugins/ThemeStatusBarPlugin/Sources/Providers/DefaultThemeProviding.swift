import Foundation
import LumiKernel
import LumiUI
import os

/// Default theme service implementation
///
/// Implements LumiUI.LumiThemeServicing protocol.
/// Responsible for managing theme contributions from plugins, persisting theme selection,
/// and syncing with the editor syntax theme system.
@MainActor
public final class DefaultThemeProviding: LumiThemeServicing {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.theme")
    nonisolated static let verbose = false

    public let themeRegistry: LumiUIThemeRegistry
    private var themeSelectionStore: ThemeSelectionStore
    private var pluginsChangedObserver: NSObjectProtocol?

    /// Reference to the plugin service for collecting theme contributions.
    private weak var pluginService: PluginManaging?

    /// Reference to the editor core service for syntax theme sync.
    private weak var editorCoreService: EditorCoreServiceType?

    public var themes: [LumiUIThemeContribution] {
        themeRegistry.themes
    }

    public var selectedThemeId: String? {
        themeRegistry.selectedThemeId
    }

    public var selectedContribution: LumiUIThemeContribution? {
        themeRegistry.selectedContribution
    }

    public func selectTheme(id: String) throws {
        try themeRegistry.select(themeId: id)
        themeSelectionStore.save(selectedThemeID: id)
    }

    public init(
        themeRegistry: LumiUIThemeRegistry = .shared,
        pluginService: PluginManaging? = nil,
        editorCoreService: EditorCoreServiceType? = nil
    ) {
        self.themeRegistry = themeRegistry
        self.themeSelectionStore = ThemeSelectionStore.shared
        self.pluginService = pluginService
        self.editorCoreService = editorCoreService

        if Self.verbose {
            Self.logger.info("Initializing DefaultThemeProviding")
        }

        // Restore saved theme selection
        restoreSavedThemeIfPossible()

        // Subscribe to system appearance changes
        themeRegistry.onSystemAppearanceDidChange = { [weak self] in
            self?.syncEditorTheme()
        }

        // Subscribe to plugin enable/disable changes: reload themes when plugins change
        pluginsChangedObserver = NotificationCenter.default.addObserver(
            forName: .lumiEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadThemes()
        }

        if Self.verbose {
            Self.logger.info("DefaultThemeProviding initialized")
        }
    }

    /// Inject the plugin service after `LumiKernel.plugin` becomes available.
    ///
    /// `DefaultThemeProviding.init` runs during `ThemeStatusBarPlugin.register(kernel:)`,
    /// but `kernel.plugin` is `nil` at that point (PluginManagementPlugin hasn't been
    /// registered yet). The plugin service is wired up in `boot(kernel:)` and the
    /// themes are reloaded then.
    public func setPluginService(_ service: PluginManaging) {
        self.pluginService = service
        if Self.verbose {
            Self.logger.info("Plugin service injected")
        }
    }

    /// Reload themes from all enabled plugins' theme contributions.
    public func reloadThemes() {
        guard let pluginService else {
            // Fallback: use built-in theme only
            if Self.verbose {
                Self.logger.info("No plugin service available; using built-in theme")
            }
            return
        }

        // Collect theme contributions from plugins that implement UIThemeProviding.
        // Note: Theme plugins register themes via kernel.registerTheme() which adds
        // directly to themeRegistry. Those themes are preserved here.
        var contributions: [LumiUIThemeContribution] = []
        for plugin in pluginService.allPlugins {
            if let themeProvider = plugin as? any UIThemeProviding {
                contributions.append(contentsOf: themeProvider.themeContributions())
            }
        }

        if contributions.isEmpty {
            // No UIThemeProviding plugins found. Preserve existing registered themes
            // (from kernel.registerTheme calls) instead of wiping them.
            if Self.verbose {
                Self.logger.info("No UIThemeProviding contributions; preserving \(self.themeRegistry.themes.count) existing themes")
            }
        } else {
            do {
                // Merge UIThemeProviding contributions with existing registered themes,
                // avoiding duplicates by theme ID.
                let existingThemes = self.themeRegistry.themes
                var merged = contributions
                for existing in existingThemes {
                    if !merged.contains(where: { $0.id == existing.id }) {
                        merged.append(existing)
                    }
                }
                try themeRegistry.replaceAll(merged)
                if Self.verbose {
                    Self.logger.info("Reloaded \(merged.count) theme contributions (merged with existing)")
                }
            } catch {
                Self.logger.error("Failed to replace themes: \(error)")
            }
        }

        // After reloading, restore the previously saved theme selection if possible
        restoreSavedThemeSelection()
    }

    /// Connect to the editor core service for syntax theme synchronization.
    public func connectEditorThemeSync(_ service: EditorCoreServiceType) {
        self.editorCoreService = service
        syncEditorTheme()
    }

    /// Register a theme contribution (compatibility with legacy API).
    public func registerTheme(_ theme: LumiUIThemeContribution) {
        try? themeRegistry.replaceAll(themeRegistry.themes + [theme])
    }

    /// Unregister a theme contribution (compatibility with legacy API).
    public func unregisterTheme(id: String) {
        let remaining = themeRegistry.themes.filter { $0.id != id }
        if remaining.isEmpty {
            try? themeRegistry.replaceAll([.builtInFallback()])
        } else {
            try? themeRegistry.replaceAll(remaining)
        }
    }

    /// Replace all theme contributions (compatibility with legacy API).
    public func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws {
        try themeRegistry.replaceAll(themes)
    }

    // MARK: - Private

    /// Restore the saved theme selection on initialization.
    private func restoreSavedThemeIfPossible() {
        guard let savedThemeID = themeSelectionStore.selectedThemeID else {
            return
        }
        // The theme will be available after reloadThemes() is called.
        // We store the preference and apply it after themes are loaded.
        if Self.verbose {
            Self.logger.info("Saved theme ID: \(savedThemeID)")
        }
    }

    /// After themes are reloaded, select the previously saved theme if it exists.
    private func restoreSavedThemeSelection() {
        guard let savedThemeID = themeSelectionStore.selectedThemeID else {
            return
        }
        // Check if the saved theme is now available
        if themeRegistry.themes.contains(where: { $0.id == savedThemeID }) {
            do {
                try themeRegistry.select(themeId: savedThemeID)
                if Self.verbose {
                    Self.logger.info("Restored saved theme: \(savedThemeID)")
                }
            } catch {
                Self.logger.error("Failed to select saved theme: \(error)")
            }
        }
    }

    /// Sync the editor syntax theme to match the current UI theme.
    private func syncEditorTheme() {
        editorCoreService?.syncAppSyntaxThemes()
    }
}

/// Minimal protocol for editor core service dependency.
/// Avoids importing the full EditorCoreService type into this module.
public protocol EditorCoreServiceType: AnyObject {
    func syncAppSyntaxThemes()
}
