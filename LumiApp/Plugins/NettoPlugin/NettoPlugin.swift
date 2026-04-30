import MagicKit
import SwiftUI
import os

actor NettoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
    nonisolated static let emoji = "🛡️"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = false

    static let id = "Netto"
    static let navigationId = "netto_firewall"
    static let displayName = String(localized: "Netto Firewall", table: "Netto")
    static let description = String(localized: "Manage network permissions for macOS applications.", table: "Netto")
    static let iconName = "puzzlepiece"
    static var order: Int { 99 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = NettoPlugin()
    
    // MARK: - UI Contributions

    /// 该面板不需要右侧栏

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == "shield.lefthalf.filled" else { return nil }
        return AnyView(NettoDashboardView())
    }

    nonisolated func addPanelIcon() -> String? { "shield.lefthalf.filled" }
}
