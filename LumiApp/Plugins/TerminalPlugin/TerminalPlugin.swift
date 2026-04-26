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

    // MARK: - Lifecycle
    
    nonisolated func onRegister() {}
    
    nonisolated func onEnable() {}
    
    nonisolated func onDisable() {}
    
    // MARK: - UI

    /// 该面板不需要右侧栏
    nonisolated var panelNeedsSidebar: Bool { false }

    @MainActor
    func addPanelView() -> AnyView? {
        AnyView(TerminalMainView())
    }
}
