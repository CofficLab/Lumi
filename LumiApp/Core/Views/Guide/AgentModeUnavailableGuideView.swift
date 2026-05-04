import SwiftUI

/// Agent 模式不可用时的提示视图
struct AgentModeUnavailableGuideView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        let theme = themeVM.activeAppTheme

        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppUI.Color.semantic.warning)
            Text("Agent 模式不可用")
                .font(AppUI.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.workspaceTextColor())
            Text("当前没有任何 LLM 供应商插件已注册。\n请安装并启用至少一个提供 LLM 供应商的插件后重试。")
                .font(AppUI.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.workspaceSecondaryTextColor())
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
