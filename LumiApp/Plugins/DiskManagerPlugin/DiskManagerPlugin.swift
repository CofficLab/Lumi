import MagicKit
import SwiftUI

actor DiskManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💿"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "DiskManager"
    static let navigationId = "disk_manager"
    static let displayName = "Disk Manager"
    static let description = "Disk space analysis and large file cleaning"
    static let iconName = "internaldrive"
    static var order: Int { 22 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DiskManagerPlugin()

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
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
        .hideTabPicker()
        .withNavigation(DiskManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
