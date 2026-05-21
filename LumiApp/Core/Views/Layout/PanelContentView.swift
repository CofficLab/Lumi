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
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()
        let hasBottomTabs = pluginProvider.hasBottomPanelTabs()
        let showBottomPanel = hasBottomTabs && layoutVM.bottomPanelVisible
        let showContentPanel = layoutVM.contentPanelVisible

        Group {
            if let activeItem {
                VSplitView {
                    // ── 上半部分：Header + 主内容 ──
                    if showContentPanel {
                        VStack(spacing: 0) {
                            ForEach(headerViews.indices, id: \.self) { index in
                                headerViews[index]
                                    // 确保 header 视图在 activeItem 切换时能正确触发 onAppear
                                    .id("header-\(activeItem.id)-\(index)")
                            }

                            activeItem.view
                                // Panel 内容切换时平滑过渡
                                .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
                                .id(activeItem.id)
                        }
                    } else {
                        Color.clear
                            .frame(maxHeight: 0)
                    }

                    // ── 下半部分：全局底部面板 ──
                    if showBottomPanel {
                        PanelBottomView()
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
