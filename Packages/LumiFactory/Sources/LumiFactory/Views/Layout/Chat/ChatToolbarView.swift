import LumiKernel
import LumiUI
import SwiftUI

/// Chat 工具栏视图
///
/// 自己从 `kernel.sharedUI` 取出 toolbar items 与 bar items，
/// 按 leading / trailing / bar 三个位置渲染。
struct ChatToolbarView: View {
    @ObservedObject var kernel: LumiKernel

    private var toolbarItems: [ChatSectionToolbarItem] {
        kernel.sharedUI?.allChatSectionToolbarItems ?? []
    }

    private var toolbarBarItems: [ChatSectionToolbarBarItem] {
        kernel.sharedUI?.allChatSectionToolbarBarItems ?? []
    }

    private var leadingToolbarItems: [ChatSectionToolbarItem] {
        toolbarItems.filter { $0.placement == .leading }
    }

    private var trailingToolbarItems: [ChatSectionToolbarItem] {
        toolbarItems.filter { $0.placement == .trailing }
    }

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            backgroundStyle: .panel,
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            HStack(alignment: .center, spacing: 8) {
                ForEach(leadingToolbarItems) { item in
                    item.makeView()
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ForEach(trailingToolbarItems) { item in
                        item.makeView()
                    }
                    ForEach(toolbarBarItems) { item in
                        item.makeView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
        }
        .borderBottom()
        .shadowMd()
    }
}