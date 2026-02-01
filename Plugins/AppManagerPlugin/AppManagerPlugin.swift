import Foundation
import MagicKit
import SwiftUI

/// 应用管理插件
actor AppManagerPlugin: SuperPlugin, SuperLog {
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
