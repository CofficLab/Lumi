import SwiftUI
import os

actor TextActionsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.text-actions")
    nonisolated static let emoji = "🖱️"
    nonisolated static let verbose: Bool = true

    static let id = "TextActions"
    static let navigationId = "text_actions"
    static let displayName = String(localized: "Text Actions", table: "TextActions")
    static let description = String(localized: "Selected text actions menu", table: "TextActions")
    static let iconName = "text.cursor"
    static var category: PluginCategory { .editor }
    static var order: Int { 60 }
    nonisolated static let policy: PluginPolicy = .optIn
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = TextActionsPlugin()
    nonisolated private static let settingsStore = TextActionsPluginLocalStore()
    nonisolated private static let enabledKey = "TextActionsEnabled"

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "选中文本动作",
                subtitle: "监听文本选择并弹出可配置动作菜单。",
                icon: Self.iconName,
                accent: .purple,
                metrics: [
                    PluginPosterSupport.metric("Select", "文本选择"),
                    PluginPosterSupport.metric("Menu", "动作菜单"),
                ],
                rows: ["动作列表", "选区监控", "菜单预览"],
                chips: ["编辑器", "文本", "快捷动作"]
            ),
        ]
    }
    
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
                if TextActionsPlugin.verbose {
                                    TextActionsPlugin.logger.info("\(Self.t)Text Actions plugin enabled, feature \(Self.isEnabled ? "active" : "inactive")")
                }
            }
        }
    }
    
    nonisolated func onDisable() {
        Task { @MainActor in
            TextSelectionManager.shared.stopMonitoring()
        }
    }
    
    // MARK: - UI
    
    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(TextActionsSettingsView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
