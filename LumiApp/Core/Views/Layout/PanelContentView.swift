import SwiftUI

/// 面板内容视图：显示当前激活插件的面板内容
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()
        let bottomViews = pluginProvider.getActivePanelBottomViews()

        Group {
            if let activeItem {
                VStack(spacing: 1) {
                    ForEach(headerViews.indices, id: \.self) { index in
                        headerViews[index]
                    }

                    activeItem.view

                    ForEach(bottomViews.indices, id: \.self) { index in
                        bottomViews[index]
                    }
                }
            }
        }
    }
}
