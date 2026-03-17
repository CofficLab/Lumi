import Foundation
import MagicKit
import OSLog
import SwiftUI

actor DiskManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💿"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "DiskManager"
    static let navigationId = "disk_manager"
    static let displayName = String(localized: "Disk Manager")
    static let description = String(localized: "Disk space analysis and large file cleaning")
    static let iconName = "internaldrive"
    static var order: Int { 22 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DiskManagerPlugin()

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        if Self.verbose {
            os_log("\(self.t)注册磁盘管理导航入口")
        }
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                DiskManagerView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DiskManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
