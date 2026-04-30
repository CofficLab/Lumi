import MagicKit
import SwiftUI
import os

actor TextActionsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.text-actions")
    nonisolated static let emoji = "🖱️"
    nonisolated static let verbose: Bool = false

    static let id = "TextActions"
    static let navigationId = "text_actions"
    static let displayName = String(localized: "Text Actions", table: "TextActions")
    static let description = String(localized: "Selected text actions menu", table: "TextActions")
    static let iconName = "puzzlepiece"
    nonisolated static let enable: Bool = true
    static var order: Int { 60 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = TextActionsPlugin()
    nonisolated private static let settingsStore = TextActionsPluginLocalStore()
    nonisolated private static let enabledKey = "TextActionsEnabled"
    
    // MARK: - Settings
    
    /// 获取 Text Actions 功能是否启用
    nonisolated static var isEnabled: Bool {
        get {
            (settingsStore.object(forKey: enabledKey) as? Bool) ?? false
        }
    }
    
    /// 设置 Text Actions 功能启用状态
    nonisolated static func setEnabled(_ enabled: Bool) {
        settingsStore.set(enabled, forKey: enabledKey)
        
        // 根据设置变化启动或停止监控
        Task { @MainActor in
            if enabled {
                TextSelectionManager.shared.startMonitoring()
                _ = TextActionMenuController.shared
                if verbose {
                    logger.info("\(t)Text Actions 功能已启用，开始监控")
                }
            } else {
                TextSelectionManager.shared.stopMonitoring()
                if verbose {
                    logger.info("\(t)Text Actions 功能已禁用，停止监控")
                }
            }
        }
    }
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
        // Initialize settings default if not set
        Self.settingsStore.migrateLegacyValueIfMissing(forKey: Self.enabledKey)
        if Self.settingsStore.object(forKey: Self.enabledKey) == nil {
            // 默认不启用，让用户主动开启
            Self.settingsStore.set(false, forKey: Self.enabledKey)
        }
    }
    
    nonisolated func onEnable() {
        Task { @MainActor in
            // 根据用户设置决定是否启动监控
            if Self.isEnabled {
                TextSelectionManager.shared.startMonitoring()
                _ = TextActionMenuController.shared
            }
            
            if Self.verbose {
                TextActionsPlugin.logger.info("\(Self.t)Text Actions plugin enabled, feature \(Self.isEnabled ? "active" : "inactive")")
            }
        }
    }
    
    nonisolated func onDisable() {
        Task { @MainActor in
            TextSelectionManager.shared.stopMonitoring()
        }
    }
    
    // MARK: - UI
    
    /// 该面板不需要右侧栏

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == "cursorarrow.click.2" else { return nil }
        return AnyView(TextActionsSettingsView())
    }

    nonisolated func addPanelIcon() -> String? { "cursorarrow.click.2" }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}