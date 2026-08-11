import SwiftUI

/// SidebarView 顶部状态行。
///
/// 展示当前活跃 Goal 的图标/标题/进度文本,并提供描述弹窗、刷新、折叠
/// 三个操作入口。所有回调由 `SidebarView` 注入,本组件不持有状态机。
struct SidebarHeader: View {
    @State private var showDescriptionPopover = false

    let activeGoal: GoalDisplayItem?
    let progressText: String
    let isCollapsed: Bool

    let onToggleCollapsed: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            titleView

            Spacer()

            if activeGoal != nil {
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            descriptionButton
            refreshButton
            collapseButton
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var titleView: some View {
        if let goal = activeGoal {
            HStack(spacing: 6) {
                Image(systemName: goal.statusSystemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(goal.statusColor)
                    .frame(width: 16)

                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } else {
            Label(
                LumiPluginLocalization.string("Goal", bundle: .module),
                systemImage: "target"
            )
            .font(.headline)
        }
    }

    @ViewBuilder
    private var descriptionButton: some View {
        if let description = activeGoal?.goalDescription,
           !description.isEmpty {
            Button {
                showDescriptionPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(LumiPluginLocalization.string("Goal description", bundle: .module))
            .popover(isPresented: $showDescriptionPopover, arrowEdge: .bottom) {
                GoalDescriptionPopoverContent(text: description)
            }
        }
    }

    private var refreshButton: some View {
        Button {
            onRefresh()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .help(LumiPluginLocalization.string("Refresh", bundle: .module))
    }

    private var collapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                onToggleCollapsed()
            }
        } label: {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .help(LumiPluginLocalization.string(isCollapsed ? "Expand" : "Collapse", bundle: .module))
    }
}