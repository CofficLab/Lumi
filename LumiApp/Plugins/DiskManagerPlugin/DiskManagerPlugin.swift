import Foundation
import MagicKit
import SwiftUI
import os

actor DiskManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💿"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "DiskManager"
    static let navigationId = "disk_manager"
    static let displayName = String(localized: "Disk Manager", table: "DiskManager")
    static let description = String(localized: "Disk space analysis and large file cleaning", table: "DiskManager")
    static let iconName = "internaldrive"
    static var order: Int { 22 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DiskManagerPlugin()

    // MARK: - UI Contributions

    /// 该面板不需要右侧栏

    @MainActor func addPanelView() -> AnyView? {
        AnyView(DiskManagerView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
