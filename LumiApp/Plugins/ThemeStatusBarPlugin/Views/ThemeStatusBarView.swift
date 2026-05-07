import SwiftUI

/// 统一主题选择器（全局状态栏入口）：
/// 直接操作 ThemeVM 的单一主题状态。
struct ThemeStatusBarView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        StatusBarHoverContainer(
            detailView: ThemePickerDetailView(),
            popoverWidth: 320,
            id: "lumi-theme-picker"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 11))
                if let current = themeVM.currentTheme {
                    Text(current.displayName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

