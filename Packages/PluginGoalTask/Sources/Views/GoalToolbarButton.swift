import SwiftUI

// MARK: - Goal Toolbar Button

/// 显示在 chat 工具栏的 Goal 按钮(Verbosity 按钮右侧),点击展示当前对话的所有 Goal 列表。
///
/// 数据来自外部注入的 `GoalVM`(由 `Plugin` 持有,与 `SidebarView` 共享同一份数据)。
/// 弹窗内容与单行渲染分别位于 `GoalPopoverContent.swift` 与 `GoalRowView.swift`。
struct GoalToolbarButton: View {
    @ObservedObject var viewModel: GoalVM
    @State private var isPopoverPresented = false

    init(viewModel: GoalVM) {
        self.viewModel = viewModel
    }

    /// 所有 Goal 中已完成 / 已跳过的 task 数与总 task 数。
    private var progress: (completed: Int, total: Int) {
        let allTasks = viewModel.goals.flatMap(\.tasks)
        let completed = allTasks.filter { $0.status == .completed || $0.status == .skipped }.count
        return (completed, allTasks.count)
    }

    /// 是否有活跃(非终态)Goal。
    private var hasActiveGoal: Bool {
        viewModel.goals.contains { $0.goal.isTerminal == false }
    }

    var body: some View {
        if viewModel.goals.count > 0 {
            Button {
                Task {
                    await viewModel.refresh()
                }
                isPopoverPresented.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "target")
                        .font(.system(size: 10, weight: .medium))
                    if progress.total > 0 {
                        Text("\(progress.completed)/\(progress.total)")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .foregroundColor(progressColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Color.secondary.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(helpText)
            .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                GoalPopoverContent(viewModel: viewModel)
                    .frame(width: 320, height: 400)
            }
        }
    }

    // MARK: - Helpers

    private var progressColor: Color {
        guard progress.total > 0 else { return .secondary }
        if hasActiveGoal {
            let ratio = Double(progress.completed) / Double(progress.total)
            if ratio >= 1.0 { return .green.opacity(0.85) }
            return .secondary
        }
        // 所有 Goal 均已终态
        return .secondary
    }

    private var helpText: String {
        guard progress.total > 0 else {
            return LumiPluginLocalization.string("Goals", bundle: .module)
        }
        return LumiPluginLocalization.string(
            "Goals: \(progress.completed)/\(progress.total) tasks completed",
            bundle: .module
        )
    }
}
