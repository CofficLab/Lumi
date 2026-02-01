import MagicKit
import SwiftUI

actor XcodeCleanerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🛠️"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "XcodeCleaner"
    static let navigationId = "xcode_cleaner"
    static let displayName = "Xcode 清理"
    static let description = "清理 Xcode 缓存、DerivedData 和旧的设备支持文件"
    static let iconName = "hammer"
    static var order: Int { 40 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = XcodeCleanerPlugin()

    init() {}

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "xcode_cleaner",
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                XcodeCleanerView()
            },
        ]
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(XcodeCleanerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
