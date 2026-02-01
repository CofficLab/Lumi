import Foundation
import MagicKit
import SwiftUI

/// 应用管理插件
actor AppManagerPlugin: SuperPlugin {
    static let id = "com.coffic.lumi.plugin.appmanager"
    static let navigationId = "\(id).apps"

    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: "应用管理",
                icon: "apps.ipad",
                pluginId: Self.id,
                isDefault: false
            ) {
                AnyView(AppManagerView())
            }
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
