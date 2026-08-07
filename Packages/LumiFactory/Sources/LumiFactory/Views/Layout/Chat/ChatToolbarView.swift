import LumiKernel
import LumiUI
import SwiftUI

/// Chat 工具栏视图
///
/// 自己从 `kernel.sharedUI` 取出 toolbar items 与 bar items，
/// 按 leading / trailing / bar 三个位置渲染。
struct ChatToolbarView: View {
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    // 父视图 ChatView 是条件 body，切换容器时本视图可能被重建，
    // 在 init 阶段同步绑定以避免 .task 异步绑定的时序竞争。
    @StateObject private var workspaceBox: ObservableWorkspaceBox

    private var toolbarItems: [ChatSectionToolbarItem] {
        workspaceBox.service?.allChatSectionToolbarItems ?? []
    }

    private var toolbarBarItems: [ChatSectionToolbarBarItem] {
        workspaceBox.service?.allChatSectionToolbarBarItems ?? []
    }

    private var leadingToolbarItems: [ChatSectionToolbarItem] {
        toolbarItems.filter { $0.placement == .leading }
    }

    private var trailingToolbarItems: [ChatSectionToolbarItem] {
        toolbarItems.filter { $0.placement == .trailing }
    }

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _workspaceBox = StateObject(wrappedValue: ObservableWorkspaceBox(service: kernel.workspace))
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
