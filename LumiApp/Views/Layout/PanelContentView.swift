import LumiCoreKit
import LumiUI
import SwiftUI

/// 面板内容视图：显示当前激活插件的主内容区域
///
/// 布局结构（参考 VSCode）：
/// - Header 区域（由各插件提供）
/// - 插件主内容视图（带平滑切换过渡）
struct PanelContentView: View {
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var layoutVM: WindowLayoutVM
    @Environment(\.windowContainer) private var windowContainer

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeItem = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            supportsAIChat: activeItem?.supportsAIChat ?? false,
            showsProjectToolbar: activeItem?.showsProjectToolbar ?? false,
            showsRail: activeItem?.showsRail ?? false,
            windowId: windowContainer?.id
        )
        let headerViews = pluginProvider.getActivePanelHeaderViews(context: pluginContext)

        Group {
            if let activeItem {
                VStack(spacing: 0) {
                    PanelHeaderView(
                        activeItemId: activeItem.id,
                        headerViews: headerViews
                    )

                    activeItem.makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Panel 内容切换时平滑过渡
                        .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
                        .id(activeItem.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
            }
        }
    }
}
