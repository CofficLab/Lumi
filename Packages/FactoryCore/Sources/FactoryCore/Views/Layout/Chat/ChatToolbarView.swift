import KernelLumi
import LumiUI
import SwiftUI

/// Chat 工具栏视图
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次初值，监听 `.workspaceContributionsDidChange`
/// 重新拉取两个清单（toolbar items + toolbar bar items）。
struct ChatToolbarView: View {
    let kernel: KernelLumi

    @State private var toolbarItems: [ChatSectionToolbarItem] = []
    @State private var toolbarBarItems: [ChatSectionToolbarBarItem] = []

    private var leadingToolbarItems: [ChatSectionToolbarItem] {
        toolbarItems.filter { $0.placement == .leading }
    }

    private var trailingToolbarItems: [ChatSectionToolbarItem] {
        toolbarItems.filter { $0.placement == .trailing }
    }

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _toolbarItems = State(initialValue: kernel.workspace?.allChatSectionToolbarItems ?? [])
        _toolbarBarItems = State(initialValue: kernel.workspace?.allChatSectionToolbarBarItems ?? [])
    }

    private func reload() {
        toolbarItems = kernel.workspace?.allChatSectionToolbarItems ?? []
        toolbarBarItems = kernel.workspace?.allChatSectionToolbarBarItems ?? []
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
        .onWorkspaceContributionsDidChange { reload() }
    }
}
