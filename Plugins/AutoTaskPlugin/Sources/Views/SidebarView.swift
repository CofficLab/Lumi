import SwiftUI
import SuperLogKit
import LumiCoreKit

/// 右侧栏视图
///
/// 展示当前会话的任务列表，由 Plugin 通过 `addSidebarSections()` 注册。
/// 通过闭包参数获取当前会话 ID 和背景色，避免对 App 侧类型的直接依赖。
public struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @State private var isCollapsed = false

    /// 获取当前会话 ID 的闭包（内部统一为 String?）
    private let conversationIdProvider: () -> String?

    /// 获取背景色的闭包
    private let backgroundColorProvider: () -> Color

    private static let headerHeight: CGFloat = 44
    private static let maxTaskListHeight: CGFloat = 160
    fileprivate static let rowHeight: CGFloat = 30

    /// 是否有正在进行的任务（需要显示 UI）
    private var hasVisibleTasks: Bool {
        guard let summary = viewModel.summary, !summary.isEmpty else { return false }
        return !summary.isAllDone
    }

    public init(
        conversationIdProvider: @escaping () -> UUID?,
        backgroundColorProvider: @escaping () -> Color = { Color.clear }
    ) {
        self.conversationIdProvider = { conversationIdProvider()?.uuidString }
        self.backgroundColorProvider = backgroundColorProvider
    }

    public var body: some View {
        VStack(spacing: 0) {
            if hasVisibleTasks {
                headerView

                if isCollapsed {
                    EmptyView()
                } else if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.vertical, 8)
                } else {
                    taskListView
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: hasVisibleTasks ? sidebarHeight : 0)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minWidth: hasVisibleTasks ? 240 : 0, idealWidth: hasVisibleTasks ? 320 : 0)
        .background {
            if hasVisibleTasks {
                backgroundColorProvider()
                    .opacity(0.82)
            }
        }
        .overlay {
            if hasVisibleTasks {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .task(id: conversationIdProvider()) {
            await viewModel.refresh(conversationId: conversationIdProvider())
        }
        .onDisappear {
            viewModel.removeObserver()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LumiPluginLocalization.string("Task List", bundle: .module))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Label(LumiPluginLocalization.string("Tasks", bundle: .module), systemImage: "checklist")
                .font(.headline)

            Spacer()

            if let summary = viewModel.summary, !summary.isEmpty {
                Text("\(summary.completed + summary.skipped)/\(summary.total) (\(summary.completionPercent)%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.forceRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(LumiPluginLocalization.string("Refresh", bundle: .module))

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(isCollapsed
                ? LumiPluginLocalization.string("Expand", bundle: .module)
                : LumiPluginLocalization.string("Collapse", bundle: .module)
            )
        }
        .padding(.horizontal, 12)
        .frame(height: Self.headerHeight)
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(viewModel.tasks) { task in
                    TaskRowView(task: task)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(height: taskListHeight)
    }

    private var taskListHeight: CGFloat {
        guard !viewModel.tasks.isEmpty else { return 0 }
        let contentHeight = CGFloat(viewModel.tasks.count) * Self.rowHeight
            + CGFloat(max(0, viewModel.tasks.count - 1)) * 4
            + 8
        return min(contentHeight, Self.maxTaskListHeight)
    }

    private var sidebarHeight: CGFloat {
        guard hasVisibleTasks else { return 0 }
        if isCollapsed {
            return Self.headerHeight
        }
        if viewModel.isLoading {
            return Self.headerHeight + 32
        }
        return Self.headerHeight + taskListHeight
    }
}

// MARK: - Task Row

private struct TaskRowView: View {
    let task: TaskDisplayItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: task.statusSystemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(task.statusColor)
                .frame(width: 14)

            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: SidebarView.rowHeight)
        .background(Color.orange.opacity(0.075))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
