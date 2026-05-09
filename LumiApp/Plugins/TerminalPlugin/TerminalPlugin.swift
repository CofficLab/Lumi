import MagicKit
import SwiftUI

actor TerminalPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "Terminal"
    static let navigationId: String = "terminal"
    static let displayName = String(localized: "Terminal", table: "Terminal")
    static let description = String(localized: "Native interactive terminal powered by SwiftTerm", table: "Terminal")
    static let iconName = "terminal"
    static let isConfigurable: Bool = false
    static var order: Int { 90 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = TerminalPlugin()

    // MARK: - Editor Extensions

    /// 提供编辑器扩展（底部终端面板）
    nonisolated var providesEditorExtensions: Bool { true }

    /// 注册编辑器扩展到编辑器扩展注册中心
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerPanelContributor(TerminalPanelContributor())

        // 注册打开终端面板命令
        registry.registerCommandContributor(TerminalCommandContributor())
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {}

    nonisolated func onEnable() {}

    nonisolated func onDisable() {}

    // MARK: - UI (Sidebar Panel)

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(TerminalMainView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }
}
