import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 响应详细程度切换插件
///
/// 在右侧栏底部工具栏注入简洁/正常/详细切换按钮。
/// 通过 `VerbosityPreferenceContext` 读写当前详细程度状态。
public actor VerbosityPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.verbosity")

    public nonisolated static let emoji = "📝"
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let verbose: Bool = false
    public static let id = "Verbosity"
    public static let displayName = String(localized: "Verbosity", bundle: .module)
    public static let description = String(localized: "Switch between Brief, Normal, and Detailed response styles", bundle: .module)
    public static let iconName = "text.alignleft"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 84 }
    public static let shared = VerbosityPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor public func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.showChat.isVisible else { return [] }
        return [
            SidebarToolbarItem(
                id: "verbosity-toggle",
                title: String(localized: "Verbosity", bundle: .module),
                systemImage: "text.alignleft",
                priority: 11
            )
        ]
    }

    @MainActor public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "verbosity-toggle" else { return nil }
        guard let verbosityPreferenceContext = context.verbosityPreferenceContext else { return nil }
        return AnyView(VerbosityToolbarButton(verbosityContext: verbosityPreferenceContext))
    }
}
