import LumiUI
import SwiftUI

/// 标题栏分支胶囊：显示当前分支名，点击弹出分支列表。
///
/// 视觉上与 Projects 胶囊保持一致（同为 `placement: .center` 段的小控件），
/// 但只有当前项目是 Git 仓库时才渲染。
struct GitBranchToolbarButton: View {
    @LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference
    @ObservedObject private var viewModel: GitBranchToolbarViewModel
    @State private var isPopoverPresented = false
    @State private var isHovering = false

    init(viewModel: GitBranchToolbarViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .semibold))

                Text(displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                // 下拉箭头：明示这是一个可展开的控件，而非静态标签；
                // 弹层展开时翻转为向上，给出"已展开/可收起"的反馈。
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .appSurface(
                style: isHighlighted ? .listRowHover : .listRow,
                cornerRadius: 6,
                borderColor: isHighlighted ? theme.appHoverBorder : nil
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            GitBranchPopoverView(viewModel: viewModel)
        }
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHighlighted)
    }

    /// 胶囊标题：优先显示当前分支名，无分支时回退到占位文案。
    private var displayTitle: String {
        if let currentBranch = viewModel.currentBranch, !currentBranch.isEmpty {
            return currentBranch
        }
        return pluginLocalization.string("Branch")
    }

    /// 控件是否应显示高亮（悬停或弹层已展开）。
    private var isHighlighted: Bool {
        isHovering || isPopoverPresented
    }
}
