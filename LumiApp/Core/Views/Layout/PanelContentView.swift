import SwiftUI

/// 面板内容视图：显示当前激活插件的面板内容
///
/// 根据 `PluginVM.activePanelIcon` 找到匹配的插件，
/// 通过 `getActivePanelItem()` 获取其面板视图。
/// 同时在面板上方渲染所有插件提供的 Panel Header 视图。
/// 每个插件的宽度比例独立持久化（UserDefaults key: `Split.Panel.<pluginId>`）。
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()

        Group {
            if let activeItem {
                VStack(spacing: 0) {
                    // Panel Header 视图（由其他插件提供，如 EditorTabStripPlugin）
                    ForEach(headerViews.indices, id: \.self) { index in
                        headerViews[index]
                    }

                    // 面板主体内容
                    activeItem.view
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .background(SplitViewWidthPersistence(storageKey: "Split.Panel.\(activeItem.id)"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
