import SwiftUI

/// 编辑器未选择文件时的空白占位视图
struct EditorEmptyStateView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Select a file to start editing", table: "LumiEditor"))
                .font(.system(size: 13))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }
}

// MARK: - Preview

#Preview {
    EditorEmptyStateView()
        .inRootView()
}
