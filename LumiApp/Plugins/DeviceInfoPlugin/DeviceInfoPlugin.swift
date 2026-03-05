import AppKit
import Foundation
import SwiftUI

/// 设备信息插件：展示当前设备的详细信息
actor DeviceInfoPlugin: SuperPlugin {
    // MARK: - Plugin Properties

    static let id: String = "DeviceInfoPlugin"
    static let navigationId = "\(id).dashboard"
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

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
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
