import SwiftUI

/// 编辑器插件状态栏数据模型与业务逻辑
@MainActor
final class EditorLoadedPluginsViewModel: ObservableObject {

    /// 插件信息
    struct PluginInfo: Identifiable {
        let id: String
        let displayName: String
        let description: String
    }

    /// 已启用的编辑器插件列表
    @Published var enabledPlugins: [PluginInfo] = []

    /// 插件管理器（通过环境变量注入）
    var pluginVM: PluginVM?

    /// 刷新插件列表
    func refresh() {
        guard let pluginVM else { return }
        enabledPlugins = pluginVM.plugins
            .filter { plugin in
                pluginVM.isPluginEnabled(plugin) && plugin.providesEditorExtensions
            }
            .map { plugin in
                let type = type(of: plugin)
                return PluginInfo(
                    id: type.id,
                    displayName: type.displayName,
                    description: type.description
                )
            }
    }
}
