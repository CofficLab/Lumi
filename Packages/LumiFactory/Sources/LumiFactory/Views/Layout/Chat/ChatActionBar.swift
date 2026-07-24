import LumiKernel
import LumiUI
import SwiftUI

/// Chat 动作栏视图
///
/// 位于消息列表与输入框之间，用于显示插件贡献的动作栏按钮，
/// 例如模型选择、快捷操作等功能入口。
struct ChatActionBar: View {
    @ObservedObject var kernel: LumiKernel

    private var actionBarItems: [ChatSectionActionBarItem] {
        kernel.sharedUI?.allChatSectionActionBarItems ?? []
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
}
