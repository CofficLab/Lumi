import SwiftUI

/// Rail 视图冲突时的错误提示视图
///
/// 当多个插件同时提供 Rail 视图时显示此视图，告知开发者只能有一个插件提供 Rail。
struct RailConflictGuideView: View {
    /// 冲突的插件 ID 列表
    let conflictingPluginIds: [String]

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme

        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppUI.Color.semantic.error)

            Text("Rail 视图冲突")
                .font(AppUI.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.workspaceTextColor())

            Text("以下插件同时提供了 Rail 视图，但 Rail 区域只能由一个插件提供：")
                .font(AppUI.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.workspaceSecondaryTextColor())

            ForEach(conflictingPluginIds, id: \.self) { id in
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece")
                        .font(.system(size: 12))
                    Text(id)
                        .font(AppUI.Typography.body)
                }
                .foregroundColor(AppUI.Color.semantic.error)
            }

            Text("请只保留一个插件的 addRailView() 实现，或禁用多余的插件。")
                .font(AppUI.Typography.caption1)
                .foregroundColor(theme.workspaceTertiaryTextColor())

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
