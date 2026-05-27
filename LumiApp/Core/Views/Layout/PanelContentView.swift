import LumiCoreKit
import LumiUI
import SwiftUI

/// 面板内容视图：显示当前激活插件的面板内容
///
/// 布局采用上下分离结构（参考 VSCode）：
/// - 上半部分：Header + 主内容区
/// - 下半部分：底部面板区（可拖拽分隔线调节高度）
struct PanelContentView: View {
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var layoutVM: WindowLayoutVM

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeItem = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            supportsAIChat: activeItem?.supportsAIChat ?? false,
            showsProjectToolbar: activeItem?.showsProjectToolbar ?? false
        )
        let headerViews = pluginProvider.getActivePanelHeaderViews(context: pluginContext)
        let hasBottomTabs = pluginProvider.hasBottomPanelTabs(context: pluginContext)
        let showBottomPanel = hasBottomTabs && layoutVM.bottomPanelVisible
        let showContentPanel = layoutVM.contentPanelVisible

        Group {
            if showContentPanel, let activeItem, showBottomPanel {
                VSplitView {
                    contentPanel(activeItem: activeItem, headerViews: headerViews)
                    PanelBottomView()
                        .background(SplitViewWidthPersistence(
                            storageKey: "Split.PanelContent.BottomPanel",
                            columnIndex: 1
                        ))
                }
            } else if showContentPanel, let activeItem {
                contentPanel(activeItem: activeItem, headerViews: headerViews)
            } else if showBottomPanel {
                PanelBottomView()
            } else {
                Color.clear
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

    // ── 上半部分：Header + 主内容 ──
    private func contentPanel(activeItem: ViewContainerItem, headerViews: [AnyView]) -> some View {
        VStack(spacing: 0) {
            ForEach(headerViews.indices, id: \.self) { index in
                headerViews[index]
                    // 确保 header 视图在 activeItem 切换时能正确触发 onAppear
                    .id("header-\(activeItem.id)-\(index)")
            }

            activeItem.makeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Panel 内容切换时平滑过渡
                .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
                .id(activeItem.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
