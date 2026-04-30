import MagicKit
import SwiftUI
import os

actor BrewManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")

    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🍺"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true
    
    static let id = "BrewManager"
    static let navigationId = "brew_manager"
    static let displayName = String(localized: "Package Management", table: "BrewManager")
    static let description = String(localized: "Manage Homebrew packages and casks", table: "BrewManager")
    static let iconName = "puzzlepiece"
    static var order: Int { 60 }
    nonisolated var instanceLabel: String { Self.id }
    static let shared = BrewManagerPlugin()
    
    // MARK: - UI Contributions

    /// 该面板不需要右侧栏

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == "shippingbox" else { return nil }
        return AnyView(BrewManagerView())
    }

    nonisolated func addPanelIcon() -> String? { "shippingbox" }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
