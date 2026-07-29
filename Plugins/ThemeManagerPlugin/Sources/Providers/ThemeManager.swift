import Foundation
import LumiKernel
import LumiUI
import os

/// Default theme service implementation
///
/// Implements LumiKernel.UIThemeProviding protocol.
/// Responsible for managing theme contributions from plugins and persisting theme selection.
/// Theme changes are broadcast via the kernel event dispatcher; subscribers (e.g. the editor
/// service) react on their own without ThemeManager knowing about them.
@MainActor
public final class ThemeManager: UIThemeProviding {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.theme")
    nonisolated static let verbose = false

    public let themeRegistry: LumiUIThemeRegistry
    private var themeSelectionStore: ThemeSelectionStore
    private var pluginsChangedObserver: NSObjectProtocol?

    /// Reference to the plugin manager for collecting theme contributions.
    private weak var pluginManager: BuiltinPluginManager?

    /// Kernel event dispatcher, used to broadcast theme-change events.
    private weak var eventManager: EventManager?

    public var themes: [LumiUIThemeContribution] {
        themeRegistry.themes
    }

    public func themeContributions() -> [LumiUIThemeContribution] {
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
        postThemeDidChange()
    }

    public init(
        themeRegistry: LumiUIThemeRegistry = .shared,
        pluginManager: BuiltinPluginManager? = nil
    ) {
        self.themeRegistry = themeRegistry
        self.themeSelectionStore = ThemeSelectionStore.shared
        self.pluginManager = pluginManager

        if Self.verbose {
            Self.logger.info("Initializing DefaultThemeProviding")
        }

        // Restore saved theme selection
        restoreSavedThemeIfPossible()

        // Subscribe to system appearance changes
        themeRegistry.onSystemAppearanceDidChange = { [weak self] in
            self?.postThemeDidChange()
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

    /// Inject the plugin manager after `LumiKernel.pluginManager` becomes available.
    ///
    /// `ThemeManager.init` runs during `ThemeManagerPlugin.onBoot(kernel:)`,
    /// but the plugin manager may not be fully initialized at that point.
    /// The plugin manager is wired up here and themes are reloaded.
    public func setPluginManager(_ manager: BuiltinPluginManager) {
        self.pluginManager = manager
        if Self.verbose {
            Self.logger.info("Plugin manager injected")
        }
    }

    /// Inject the kernel event manager used to broadcast theme-change events.
    public func setEventManager(_ eventManager: EventManager) {
        self.eventManager = eventManager
    }

    /// Reload themes from all enabled plugins' theme contributions.
    public func reloadThemes() {
        guard let pluginManager else {
            // Fallback: use built-in theme only
            if Self.verbose {
                Self.logger.info("No plugin manager available; using built-in theme")
            }
            return
        }

        // Collect theme contributions from plugins that implement UIThemeProviding.
        // Note: Theme plugins register themes via kernel.registerTheme() which adds
        // directly to themeRegistry. Those themes are preserved here.
        var contributions: [LumiUIThemeContribution] = []
        for plugin in pluginManager.allPlugins {
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
        postThemeDidChange()
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

    // MARK: - UIThemeProviding

    /// 将内核持有的主题贡献同步到 LumiUI 的主题注册中心。
    ///
    /// 在 `LumiKernel.startup()` 末尾调用,确保所有插件的 `onReady` 已执行完毕。
    public func syncToLumiUI() {
        reloadThemes()
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

    /// Broadcast a theme-change event so other services (e.g. the editor)
    /// can react without ThemeManager knowing about them.
    private func postThemeDidChange() {
        eventManager?.post(.themeDidChange)
    }
}
