import SwiftUI
import os

/// 响应详细程度切换插件
///
/// 在右侧栏底部工具栏注入简洁/正常/详细切换按钮。
/// 通过 `AppLLMVM` 读写当前详细程度状态。
actor VerbosityPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.verbosity")

    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = true
    static let id = "Verbosity"
    static let displayName = String(localized: "Verbosity", table: "Verbosity")
    static let description = String(localized: "Switch between Brief, Normal, and Detailed response styles", table: "Verbosity")
    static let iconName = "text.alignleft"
    static var category: PluginCategory { .agent }
    static var order: Int { 84 }
    nonisolated static let enable: Bool = true
    static let shared = VerbosityPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [
            SidebarToolbarItem(
                id: "verbosity-toggle",
                title: String(localized: "Verbosity", table: "Verbosity"),
                systemImage: "text.alignleft",
                priority: 11
            )
        ]
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
        guard itemId == "verbosity-toggle" else { return nil }
        return AnyView(VerbosityToolbarButton())
    }
}
