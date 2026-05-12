#if canImport(LumiPreviewKit)
import SwiftUI

/// 编辑器预览空状态视图。
///
/// 当文件中未检测到 #Preview 宏时展示的占位提示。
struct EditorPreviewEmptyStateView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(String(localized: "No #Preview macros found", table: "EditorPreview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
#endif
