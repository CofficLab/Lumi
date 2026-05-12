#if canImport(LumiPreviewKit)
import SwiftUI

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
