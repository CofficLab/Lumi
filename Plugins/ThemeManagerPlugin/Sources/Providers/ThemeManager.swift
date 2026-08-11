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

    /// Command group ID for theme menu registration.
    private static let commandGroupId = "com.coffic.lumi.theme.menu"

    public let themeRegistry: LumiUIThemeRegistry
    private var themeSelectionStore: ThemeSelectionStore
    private var pluginsChangedObserver: NSObjectProtocol?

    /// Reference to the plugin manager for collecting theme contributions.
    private weak var pluginManager: PluginManager?

    /// Kernel event dispatcher, used to broadcast theme-change events.
    private weak var eventManager: EventManager?

    /// Kernel reference, used to request a rebuild of declarative command contributions.
    private weak var kernel: LumiKernel?

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
        pluginManager: PluginManager? = nil
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
    public func setPluginManager(_ manager: PluginManager) {
        self.pluginManager = manager
        if Self.verbose {
            Self.logger.info("Plugin manager injected")
        }
    }

    /// Inject the theme-selection store so the file is persisted through the
    /// `StoragePlugin` convention instead of the legacy
    /// `<Application Support>/LumiUI/theme-selection.plist` path. Must be
    /// called before any `selectTheme(id:)` that should be remembered.
    func setThemeSelectionStore(_ store: ThemeSelectionStore) {
        self.themeSelectionStore = store
        // Re-read any ID that may have already been written at the injected
        // location, so the registry reflects the user's prior choice.
        restoreSavedThemeIfPossible()
    }

    /// Inject the kernel event manager used to broadcast theme-change events.
    public func setEventManager(_ eventManager: EventManager) {
        self.eventManager = eventManager
    }

    /// Inject the kernel reference used to refresh declarative command contributions.
    public func setKernel(_ kernel: LumiKernel) {
        self.kernel = kernel
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
        guard let kernel else { return }
        kernel.pluginManager.registerPluginCommandContributions(in: kernel)
    }

    /// 根据当前主题列表和选中状态创建菜单命令组。
    func commandMenuGroup() -> CommandMenuGroup {
        let currentThemes = themeRegistry.themes
        let currentSelectedId = themeRegistry.selectedThemeId

        let items = currentThemes.map { theme in
            CommandItem(
                id: "\(Self.commandGroupId).select.\(theme.id)",
                title: theme.displayName,
                state: theme.id == currentSelectedId ? .on : .off
            ) { [weak self] in
                try? self?.selectTheme(id: theme.id)
            }
        }

        return CommandMenuGroup(
            id: Self.commandGroupId,
            name: LumiPluginLocalization.string("Theme", bundle: .module),
            items: items,
            placement: .topLevelMenu
        )
    }
}
