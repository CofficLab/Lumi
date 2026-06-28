import SwiftUI
import LumiCoreKit
import LumiUI
import SuperLogKit
import os

public actor TextActionsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.text-actions")
    public nonisolated static let emoji = "🖱️"
    public nonisolated static let verbose: Bool = false

    public static let id = "TextActions"
    public static let navigationId = "text_actions"
    public static let displayName = LumiPluginLocalization.string("Text Actions", bundle: .module)
    public static let description = LumiPluginLocalization.string("Selected text actions menu", bundle: .module)
    public static let iconName = "text.cursor"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 60 }
    public nonisolated static let policy: PluginPolicy = .optOut
    
    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = TextActionsPlugin()
    nonisolated private static let settingsStore = TextActionsPluginLocalStore()
    nonisolated private static let enabledKey = "TextActionsEnabled"

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public nonisolated static var isEnabled: Bool {
        get {
            (settingsStore.object(forKey: enabledKey) as? Bool) ?? false
        }
    }
    
    /// 设置 Text Actions 功能启用状态
    public nonisolated static func setEnabled(_ enabled: Bool) {
        settingsStore.set(enabled, forKey: enabledKey)
        
        // 根据设置变化启动或停止监控
        Task { @MainActor in
            if enabled {
                TextSelectionManager.shared.startMonitoring()
                _ = TextActionMenuController.shared
                if verbose {
                    logger.info("\(self.t)Text Actions 功能已启用，开始监控")
                }
            } else {
                TextSelectionManager.shared.stopMonitoring()
                if verbose {
                    logger.info("\(self.t)Text Actions 功能已禁用，停止监控")
                }
            }
        }
    }
    
    // MARK: - Lifecycle
    
    public nonisolated func onRegister() {
        // Initialize settings default if not set
        Self.settingsStore.migrateLegacyValueIfMissing(forKey: Self.enabledKey)
        if Self.settingsStore.object(forKey: Self.enabledKey) == nil {
            // 默认不启用，让用户主动开启
            Self.settingsStore.set(false, forKey: Self.enabledKey)
        }
    }
    
    public nonisolated func onEnable() {
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
    
    public nonisolated func onDisable() {
        Task { @MainActor in
            TextSelectionManager.shared.stopMonitoring()
        }
    }
    
    // MARK: - UI
    
    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
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
