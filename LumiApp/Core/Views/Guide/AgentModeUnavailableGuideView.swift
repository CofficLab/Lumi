import SwiftUI

/// Agent 模式不可用时的提示视图
struct AgentModeUnavailableGuideView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        let theme = themeVM.activeAppTheme

        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: "FF9F0A"))
            Text("Agent 模式不可用")
                .font(.system(size: 20, weight: .semibold))
                .fontWeight(.semibold)
                .foregroundColor(theme.workspaceTextColor())
            Text("当前没有任何 LLM 供应商插件已注册。\n请安装并启用至少一个提供 LLM 供应商的插件后重试。")
                .font(.system(size: 15, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundColor(theme.workspaceSecondaryTextColor())
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
