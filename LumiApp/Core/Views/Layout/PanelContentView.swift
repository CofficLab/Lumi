import SwiftUI

/// 面板内容视图：显示当前激活插件的面板内容
///
/// 根据 `PluginVM.activePanelIcon` 找到匹配的插件，
/// 通过 `getActivePanelItem()` 获取其面板视图。
/// 同时在面板上方渲染所有插件提供的 Panel Header 视图，
/// 在面板下方渲染所有插件提供的 Panel Bottom 视图。
/// 每个插件的宽度比例独立持久化（UserDefaults key: `Split.Panel.<pluginId>`）。
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()
        let bottomViews = pluginProvider.getActivePanelBottomViews()

        Group {
            if let activeItem {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        activeItem.view
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .clipped()
                            .padding(.top, headerOverlayHeight(headerViews))
                            .zIndex(0)

                        VStack(spacing: 0) {
                            ForEach(headerViews.indices, id: \.self) { index in
                                headerViews[index]
                            }
                        }
                        .zIndex(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    ForEach(bottomViews.indices, id: \.self) { index in
                        bottomViews[index]
                    }
                }
                .background(SplitViewWidthPersistence(storageKey: "Split.Panel.\(activeItem.id)"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func headerOverlayHeight(_ views: [AnyView]) -> CGFloat {
        // Current editor headers are fixed-height bars stacked vertically.
        // Reserving space here prevents NSView-backed editor content from
        // overlapping the interactive header hit area.
        CGFloat(views.count) * 36
    }
}
