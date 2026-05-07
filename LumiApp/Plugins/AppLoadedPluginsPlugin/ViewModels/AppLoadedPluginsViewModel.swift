import MagicKit
import SwiftUI

/// App 插件状态栏数据模型与业务逻辑
@MainActor
final class AppLoadedPluginsViewModel: ObservableObject {

    /// 插件信息
    struct PluginInfo: Identifiable {
        let id: String
        let displayName: String
        let description: String
        let order: Int
    }

    /// 已安装的 App 插件列表（从 PluginVM 获取，即真正加载到 App 的插件）
    @Published var enabledPlugins: [PluginInfo] = []

    /// 刷新插件列表
    func refresh() {
        let pluginVM = PluginVM.shared
        enabledPlugins = pluginVM.plugins.map { plugin in
            let pluginType = type(of: plugin)
            return PluginInfo(
                id: pluginType.id,
                displayName: pluginType.displayName,
                description: pluginType.description,
                order: pluginType.order
            )
        }
    }
}
