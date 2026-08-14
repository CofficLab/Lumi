import SwiftUI

/// 工具栏居中标题标签：与 Projects 插件项目列表控件同款的胶囊样式。
///
/// 用于各插件在工具栏中间区域显示的容器标题，
/// 统一使用 `listRow` 表面背景、内边距与字体规格，
/// 保证与 Projects 项目列表控件的视觉一致性。
///
/// 非交互式静态标签：可展开的交互控件（如项目列表）不适用此组件。
public struct AppToolbarTitleLabel<Trailing: View>: View {
    @LumiTheme private var theme

    let icon: String?
    let title: String
    let trailing: () -> Trailing

    public init(
        icon: String? = nil,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            trailing()
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .appSurface(style: .listRow, cornerRadius: 6)
    }
}

#Preview {
    VStack(spacing: 12) {
        AppToolbarTitleLabel(title: "Git")

        AppToolbarTitleLabel(icon: "folder", title: "Projects")

        AppToolbarTitleLabel(icon: "brain.head.profile", title: "Mind Map") {
            Text("·")
                .foregroundStyle(.tertiary)
            Text("untitled")
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Text("(3)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    .padding()
}
