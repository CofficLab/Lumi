import MagicKit
import SwiftUI
import os

actor PortManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.port-manager")
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔌"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id = "PortManager"
    static let navigationId = "port_manager"
    static let displayName = String(localized: "Port Manager", table: "PortManager")
    static let description = String(localized: "View and manage port usage", table: "PortManager")
    static let iconName = "puzzlepiece"
    static var order: Int { 20 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = PortManagerPlugin()

    init() {}

    // MARK: - UI Contributions

    /// 该面板不需要右侧栏

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == "network" else { return nil }
        return AnyView(PortManagerView())
    }

    nonisolated func addPanelIcon() -> String? { "network" }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
