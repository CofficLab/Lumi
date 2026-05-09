import SwiftUI

/// 面板内容视图：显示当前激活插件的面板内容
///
/// 布局采用上下分离结构（参考 VSCode）：
/// - 上半部分：Header + 主内容区
/// - 下半部分：底部面板区（可拖拽分隔线调节高度）
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()
        let hasBottomTabs = pluginProvider.hasBottomPanelTabs()

        Group {
            if let activeItem {
                VSplitView {
                    // ── 上半部分：Header + 主内容 ──
                    VStack(spacing: 0) {
                        ForEach(headerViews.indices, id: \.self) { index in
                            headerViews[index]
                        }

                        activeItem.view
                    }

                    // ── 下半部分：全局底部面板 ──
                    if hasBottomTabs {
                        BottomPanelBarView()
                            .background(SplitViewWidthPersistence(
                                storageKey: "Split.PanelContent.BottomPanel",
                                columnIndex: 1
                            ))
                    } else {
                        Color.clear
                            .frame(maxHeight: 0)
                    }
                }
            }
        }
    }
}
