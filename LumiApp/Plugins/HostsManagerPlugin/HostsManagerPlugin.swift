import MagicKit
import SwiftUI
import os

actor HostsManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.hosts-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "📝"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true

    static let id = "HostsManager"
    static let navigationId = "hosts_manager"
    static let displayName = String(localized: "Hosts Manager", table: "HostsManager")
    static let description = String(localized: "Manage system hosts file configuration", table: "HostsManager")
    static let iconName = "list.bullet.rectangle"
    static var order: Int { 21 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = HostsManagerPlugin()

    // MARK: - UI Contributions

    /// 该面板不需要右侧栏

    @MainActor func addPanelView() -> AnyView? {
        AnyView(HostsManagerView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
