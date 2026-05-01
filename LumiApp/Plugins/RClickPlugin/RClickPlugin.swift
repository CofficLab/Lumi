import MagicKit
import SwiftUI
import os

actor RClickPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🖱️"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = false
    
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")

    static let id = "RClick"
    static let navigationId: String? = "rclick"
    static let displayName = String(localized: "Right Click", table: "RClick")
    static let description = String(localized: "Customize Finder right-click menu actions", table: "RClick")
    static let iconName = "cursorarrow.click.2"
    static let isConfigurable: Bool = false
    static var order: Int { 50 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RClickPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        Task { @MainActor in
            _ = RClickConfigManager.shared
        }
    }

    // MARK: - UI

    

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(RClickSettingsView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
