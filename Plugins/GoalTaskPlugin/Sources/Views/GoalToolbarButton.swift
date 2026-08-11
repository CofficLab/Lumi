import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

// MARK: - Goal Toolbar Button

/// 显示在 chat 工具栏的 Goal 按钮(Verbosity 按钮右侧),点击展示当前对话的所有 Goal 列表。
///
/// 数据来自外部注入的 `GoalVM`(由 `Plugin` 持有,与 `SidebarView` 共享同一份数据)。
/// 弹窗内容与单行渲染分别位于 `GoalPopoverContent.swift` 与 `GoalRowView.swift`。
struct GoalToolbarButton: View {
    @ObservedObject var viewModel: GoalVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isPopoverPresented = false

    private var goalCount: Int {
        viewModel.goals.count
    }

    init(viewModel: GoalVM) {
        self.viewModel = viewModel
    }

    var body: some View {
        if self.viewModel.goals.count > 0 {
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
}
