import LumiKernel
import LumiUI
import SwiftUI

/// Chat 动作栏视图
///
/// 位于消息列表与输入框之间，用于显示插件贡献的动作栏按钮，
/// 例如模型选择、快捷操作等功能入口。
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次初值，监听 `.workspaceContributionsDidChange`
/// 重新拉取 action bar items。
///
/// 注意：body 用 `if !actionBarItems.isEmpty` 条件渲染。事件修饰符挂在 Group 外层
/// 而非 if 内，保证分支未渲染时仍能收到事件、下次 items 非空时能正确出现。
struct ChatActionBar: View {
    let kernel: LumiKernel

    @State private var actionBarItems: [ChatSectionActionBarItem] = []

    private var leadingActionBarItems: [ChatSectionActionBarItem] {
        actionBarItems.filter { $0.placement == .leading }
    }

    private var trailingActionBarItems: [ChatSectionActionBarItem] {
        actionBarItems.filter { $0.placement == .trailing }
    }

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _actionBarItems = State(initialValue: kernel.workspace?.allChatSectionActionBarItems ?? [])
    }

    var body: some View {
        // Group 恒存在 → `.onWorkspaceContributionsDidChange` 挂在 Group 上，
        // 即使 if 分支未渲染（items 为空）也能持续接收事件，下一次 items 非空后
        // 分支正常出现。若挂在 if 内，分支不渲染时修饰符永不绑定，永远无法恢复。
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
        .onWorkspaceContributionsDidChange {
            actionBarItems = kernel.workspace?.allChatSectionActionBarItems ?? []
        }
    }
}
