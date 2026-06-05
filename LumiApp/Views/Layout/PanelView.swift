import LumiCoreKit
import LumiUI
import SwiftUI

/// 面板组合视图：负责组合 PanelContentView 和 PanelBottomView
///
/// 参考 VSCode 的面板布局：
/// - 上半部分：PanelContentView（Header + 活跃插件主内容）
/// - 下半部分：PanelBottomView（底部面板区，可拖拽分隔线调节高度）
struct PanelView: View {
    @EnvironmentObject var layoutVM: WindowLayoutVM
    @EnvironmentObject var pluginProvider: AppPluginVM
    @Environment(\.windowContainer) private var windowContainer

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeItem = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            showChat: activeItem?.showChat ?? false,
            showsProjectToolbar: activeItem?.showsProjectToolbar ?? false,
            showsRail: activeItem?.showsRail ?? false,
            showsBottomPanel: activeItem?.showsBottomPanel ?? false,
            windowId: windowContainer?.id
        )
        let canShowBottomPanel = activeItem?.showsBottomPanel ?? false
        let hasBottomTabs = canShowBottomPanel && pluginProvider.hasBottomPanelTabs(context: pluginContext)
        let showBottomPanel = hasBottomTabs && layoutVM.bottomPanelVisible
        let showContentPanel = layoutVM.contentPanelVisible

        Group {
            if showContentPanel, activeItem != nil, showBottomPanel {
                VSplitView {
                    PanelContentView()
                    PanelBottomView()
                        .background(SplitViewWidthPersistence(
                            storageKey: "Split.Panel.BottomPanel",
                            columnIndex: 1
                        ))
                }
            } else if showContentPanel, activeItem != nil {
                PanelContentView()
            } else if showBottomPanel {
                PanelBottomView()
            } else {
                PanelEmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            Button {
                withAnimation {
                    layoutVM.editorVisible = false
                }
            } label: {
                Label("Hide Editor", systemImage: "rectangle.center.inset.filled")
            }
        }
    }
}
