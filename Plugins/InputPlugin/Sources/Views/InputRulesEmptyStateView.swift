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
            Text(String(localized: "暂无输入源切换规则", bundle: .module))
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)

            // 描述文字
            Text(String(localized: "添加应用和对应的输入源，切换应用时自动切换输入法", bundle: .module))
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
