import SwiftUI

/// 编辑器插件状态栏数据模型与业务逻辑
@MainActor
final class EditorLoadedPluginsViewModel: ObservableObject {

    /// 插件信息
    struct PluginInfo: Identifiable {
        let id: String
        let displayName: String
        let description: String
        let order: Int
    }

    /// 已安装的编辑器插件列表（从 EditorVM 获取，即真正加载到 editor 内核的插件）
    @Published var enabledPlugins: [PluginInfo] = []

    /// 刷新插件列表
    func refresh(from editorVM: EditorVM) {
        enabledPlugins = editorVM.service.state.editorFeaturePlugins.map { plugin in
            PluginInfo(
                id: plugin.id,
                displayName: plugin.displayName,
                description: plugin.description,
                order: plugin.order
            )
        }
    }
}
