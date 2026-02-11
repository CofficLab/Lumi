import SwiftUI

/// 输入源规则列表空状态视图
struct InputRulesEmptyStateView: View {
    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // 键盘图标
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            // 标题
            Text("暂无输入源切换规则")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            // 描述文字
            Text("添加应用和对应的输入源，切换应用时自动切换输入法")
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    InputRulesEmptyStateView()
        .frame(width: 400, height: 300)
}
