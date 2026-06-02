import SwiftUI

/// 主内容区域为空时的提示视图（编辑器、Rail、右侧栏均不可见时显示）
struct EmptyContentGuideView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM

    var body: some View {
        let theme = themeVM.activeChromeTheme

        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.on.rectangle")
                .font(.appLargeTitle)
                .foregroundColor(theme.workspaceSecondaryTextColor())
            Text("内容区域为空")
                .font(.appTitle)
                .foregroundColor(theme.workspaceTextColor())
            Text("请在左侧活动栏中选择一个视图以显示内容")
                .font(.appBody)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.workspaceSecondaryTextColor())
            Button {
                withAnimation {
                    layoutVM.editorVisible = true
                }
            } label: {
                Label("显示编辑器", systemImage: "rectangle.center.inset.filled")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
