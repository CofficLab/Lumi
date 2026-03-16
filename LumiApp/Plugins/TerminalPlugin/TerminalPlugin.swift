import MagicKit
import SwiftUI

actor TerminalPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true

    static let id = "Terminal"
    static let navigationId: String = "terminal"
    static let displayName = String(localized: "Terminal", table: "Terminal")
    static let description = String(localized: "Interactive terminal emulator", table: "Terminal")
    static let iconName = "terminal"
    static let isConfigurable: Bool = false
    static var order: Int { 90 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = TerminalPlugin()

    // MARK: - Lifecycle
    
    nonisolated func onRegister() {}
    
    nonisolated func onEnable() {}
    
    nonisolated func onDisable() {}
    
    // MARK: - UI
    
    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                TerminalMainView()
            }
        ]
    }
}
