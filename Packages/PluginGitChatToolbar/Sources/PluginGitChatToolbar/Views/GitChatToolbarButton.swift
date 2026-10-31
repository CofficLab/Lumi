import Foundation
import LumiUI
import SwiftUI

/// Chat Toolbar 上的 Git 胶囊按钮。
///
/// 视觉风格对齐 `SkillChatToolbarView`：图标 + 计数徽标，
/// 有变更时高亮（accentColor），无变更时 muted。点击弹出
/// ``GitChatPopoverView``。
///
/// 按钮由插件入口动态 add / remove chat toolbar bar item，保证非 Git
/// 项目时不占用任何空间。
struct GitChatToolbarButton: View {
    @ObservedObject var viewModel: GitChatToolbarViewModel
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isGitRepository)
        .help(pluginLocalization.string("Git Changes"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            GitChatPopoverView(viewModel: viewModel)
        }
        .onChange(of: viewModel.projectPath) { _, _ in
            // 项目切换：关闭弹层避免显示旧仓库数据。
            isPopoverPresented = false
        }
    }

    // MARK: - Label

    private var label: some View {
        let count = viewModel.workingChanges.count
        return HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10, weight: .medium))

            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundColor(tintColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            tintColor.opacity(0.22),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }

    private var tintColor: Color {
        let count = viewModel.workingChanges.count
        if count > 0 { return .orange }
        return Color.accentColor
    }
}
