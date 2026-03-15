import SwiftUI

/// Agent 模式右侧栏统一头部视图
///
/// 支持插件通过 leading / trailing 注入：左侧可由一个插件提供（如项目信息），右侧由多个插件注入小功能（如语言切换、设置按钮）。
struct AgentRightHeaderView: View {
    /// 左侧视图（可选，无时显示默认标题）
    let leadingView: AnyView?
    /// 右侧小功能项（多插件扁平列表）
    let trailingItems: [AnyView]

    private let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：插件提供或默认
            if let leading = leadingView {
                leading
            } else {
                defaultLeadingView
            }

            Spacer()

            // 右侧：各插件注入的小功能
            if !trailingItems.isEmpty {
                HStack(spacing: 12) {
                    ForEach(trailingItems.indices, id: \.self) { index in
                        trailingItems[index]
                            .id("header_trailing_\(index)")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var defaultLeadingView: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.accentColor)
                .padding(4)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())
            Text("Lumi")
                .font(DesignTokens.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
        }
    }
}
