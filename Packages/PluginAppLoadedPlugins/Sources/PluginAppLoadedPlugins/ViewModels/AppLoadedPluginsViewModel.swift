import Foundation
import SwiftUI

/// App 插件状态栏数据模型与业务逻辑。
@MainActor
final class AppLoadedPluginsViewModel: ObservableObject {
    @Published var enabledPlugins: [LoadedPluginInfo] = []

    private let pluginProvider: @MainActor () -> [LoadedPluginInfo]

    init(pluginProvider: @escaping @MainActor () -> [LoadedPluginInfo]) {
        self.pluginProvider = pluginProvider
    }

    func refresh() {
        enabledPlugins = pluginProvider().sorted { lhs, rhs in
            if lhs.order == rhs.order {
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            } else {
                lhs.order < rhs.order
            }
        }
    }
}
