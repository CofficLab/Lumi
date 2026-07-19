import SwiftUI
import LumiKernel
import LumiUI

/// 编辑器空白占位视图。
///
/// 当当前面板没有选中文件时显示，引导用户从文件树或其他入口选择一个文件
/// 开始编辑。
public struct EditorEmptyStateView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .thin))
                .foregroundColor(Color(hex: "98989E"))

            Text(LumiPluginLocalization.string("Select a file to start editing", bundle: .module))
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "98989E"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }
}

// MARK: - Preview

#Preview {
    EditorEmptyStateView()
        .inRootView()
}
