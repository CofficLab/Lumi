import LumiUI
import SwiftUI

/// 输入源规则列表空状态视图
public struct InputRulesEmptyStateView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // 键盘图标
            Image(systemName: "keyboard")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)

            // 标题
            Text(pluginLocalization.string("No input source switching rules"))
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)

            // 描述文字
            Text(pluginLocalization.string("Add apps and corresponding input sources to automatically switch input methods when switching apps"))
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
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
