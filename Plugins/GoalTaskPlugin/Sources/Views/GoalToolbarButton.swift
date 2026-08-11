import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

// MARK: - Goal Toolbar Button

/// 显示在 chat 工具栏的 Goal 按钮(Verbosity 按钮右侧),点击展示当前对话的所有 Goal 列表。
///
/// 本文件只保留主按钮 + 视图模型;弹窗内容与单行渲染分别位于
/// `GoalPopoverContent.swift` 与 `GoalRowView.swift`;
/// 展示模型 `GoalListItem` / `GoalDisplayItem` / `GoalTaskDisplayItem` 位于 `Models/`。
struct GoalToolbarButton: View {
    @StateObject private var viewModel: GoalToolbarViewModel
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isPopoverPresented = false

    private var goalCount: Int {
        viewModel.goals.count
    }

    init(kernel: LumiKernel) {
        _viewModel = StateObject(wrappedValue: GoalToolbarViewModel(kernel: kernel))
    }

    var body: some View {
        Button {
            Task {
                await viewModel.refresh()
            }
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            GoalPopoverContent(viewModel: viewModel)
                .frame(width: 320, height: 400)
        }
    }
}

// GoalToolbarViewModel 已迁移至 `Sources/ViewModels/GoalToolbarViewModel.swift`(internal)。