import LumiKernel
import LumiUI
import SwiftUI

/// Chat 动作栏视图
///
/// 位于消息列表与输入框之间，用于显示插件贡献的动作栏按钮，
/// 例如模型选择、快捷操作等功能入口。
struct ChatActionBar: View {
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var workspaceBox = ObservableWorkspaceBox()

    private var actionBarItems: [ChatSectionActionBarItem] {
        workspaceBox.service?.allChatSectionActionBarItems ?? []
    }

    private var leadingActionBarItems: [ChatSectionActionBarItem] {
        actionBarItems.filter { $0.placement == .leading }
    }

    private var trailingActionBarItems: [ChatSectionActionBarItem] {
        actionBarItems.filter { $0.placement == .trailing }
    }

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // actionBarItems 依赖 workspaceBox.service（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时 bind 永不执行（死锁）。Group 恒存在，保证绑定。
        Group {
            if !actionBarItems.isEmpty {
                AppToolbarContainer(
                    height: AppPanelChromeMetrics.actionBarHeight,
                    backgroundStyle: .panel,
                    padding: EdgeInsets(
                        top: AppPanelChromeMetrics.actionBarVerticalPadding,
                        leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                        bottom: AppPanelChromeMetrics.actionBarVerticalPadding,
                        trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
                    )
                ) {
                    HStack(spacing: AppPanelChromeMetrics.actionBarItemSpacing) {
                        ForEach(leadingActionBarItems) { item in
                            item.makeView()
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: AppPanelChromeMetrics.actionBarItemSpacing) {
                            ForEach(trailingActionBarItems) { item in
                                item.makeView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .borderTop()
            }
        }
        .task { workspaceBox.bind(kernel.workspace) }
    }
}
