import LumiUI
import SwiftUI
import LumiCoreKit

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
            Text(LumiPluginLocalization.string("No input source switching rules", bundle: .module))
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)

            // 描述文字
            Text(LumiPluginLocalization.string("Add apps and corresponding input sources to automatically switch input methods when switching apps", bundle: .module))
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
