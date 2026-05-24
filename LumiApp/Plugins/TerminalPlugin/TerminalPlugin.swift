import SwiftUI
import TerminalCoreKit

actor TerminalPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id = "Terminal"
    static let navigationId: String = "terminal"
    static let displayName = String(localized: "Terminal", table: "Terminal")
    static let description = String(localized: "Native interactive terminal powered by SwiftTerm", table: "Terminal")
    static let iconName = "terminal"
    static let isConfigurable: Bool = false
    static var category: PluginCategory { .developerTool }
    static var order: Int { 90 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = TerminalPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}

    nonisolated func onEnable() {}

    nonisolated func onDisable() {
        Task { @MainActor in
            TerminalTabsViewModel.shared.closeAllSessions()
        }
    }

    // MARK: - UI (Sidebar Panel)

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(TerminalMainView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }
}
