import MagicKit
import SwiftUI
import AppKit
import Foundation

/// 设备信息插件：展示当前设备的详细信息
actor DeviceInfoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = false

    static let id: String = "DeviceInfo"
    static let navigationId: String = "device_info"
    static let displayName: String = String(localized: "Device Info", table: "DeviceInfo")
    static let description: String = String(localized: "Show system status like CPU, Memory, Disk, Battery, etc.", table: "DeviceInfo")
    static let iconName: String = "macbook.and.iphone"
    static let isConfigurable: Bool = false
    static var order: Int { 10 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = DeviceInfoPlugin()

    init() {}

    // MARK: - UI Contributions

    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: String(localized: "Overview", table: "DeviceInfo"),
                icon: "macbook.and.iphone",
                pluginId: Self.id
            ) {
                DeviceInfoView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DeviceInfoPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
