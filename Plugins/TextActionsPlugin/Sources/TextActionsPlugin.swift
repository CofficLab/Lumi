import SwiftUI
import LumiCoreKit
import LumiUI
import SuperLogKit
import os

public actor TextActionsPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.text-actions")
    public nonisolated static let emoji = "🖱️"
    public nonisolated static let verbose: Bool = true

    public static let policy: LumiPluginPolicy = .optOut
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "text.cursor"

    public static let info = LumiPluginInfo(
        id: "TextActions",
        displayName: LumiPluginLocalization.string("Text Actions", bundle: .module),
        description: LumiPluginLocalization.string("Selected text actions menu", bundle: .module),
        order: 60
    )

    public nonisolated var instanceLabel: String { Self.id }
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

    public nonisolated static var isEnabled: Bool {
        get {
            (settingsStore.object(forKey: enabledKey) as? Bool) ?? false
        }
    }

    public nonisolated static func setEnabled(_ enabled: Bool) {
        settingsStore.set(enabled, forKey: enabledKey)

        Task { @MainActor in
            if enabled {
                TextSelectionManager.shared.startMonitoring()
                _ = TextActionMenuController.shared
                if verbose {
                    logger.info("Text Actions 功能已启用，开始监控")
                }
            } else {
                TextSelectionManager.shared.stopMonitoring()
                if verbose {
                    logger.info("Text Actions 功能已禁用，停止监控")
                }
            }
        }
    }

    public nonisolated func onRegister() {
        Self.settingsStore.migrateLegacyValueIfMissing(forKey: Self.enabledKey)
        if Self.settingsStore.object(forKey: Self.enabledKey) == nil {
            Self.settingsStore.set(false, forKey: Self.enabledKey)
        }
    }

    public nonisolated func onEnable() {
        Task { @MainActor in
            if Self.isEnabled {
                TextSelectionManager.shared.startMonitoring()
                _ = TextActionMenuController.shared
            }

            if Self.verbose {
                logger.info("Text Actions plugin enabled, feature \(Self.isEnabled ? "active" : "inactive")")
            }
        }
    }

    public nonisolated func onDisable() {
        Task { @MainActor in
            TextSelectionManager.shared.stopMonitoring()
        }
    }

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(TextActionsSettingsView())
        }
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
