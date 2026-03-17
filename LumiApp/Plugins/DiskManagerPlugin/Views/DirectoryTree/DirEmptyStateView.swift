import SwiftUI

/// 空状态视图 - 用于显示暂无数据提示
struct DirEmptyStateView: View {
    let title: String
    let description: String
    let iconName: String

    init(
        title: String = "暂无数据",
        description: String = "",
        iconName: String = "folder"
    ) {
        self.title = title
        self.description = description
        self.iconName = iconName
    }

    var body: some View {
        ContentUnavailableView {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                .padding(.bottom, 8)
        } description: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
        }
    }
}

