import SwiftUI
import LumiUI

/// 统一主题选择器（全局状态栏入口）：
/// 直接操作 LumiUIThemeRegistry 的单一主题状态。
struct ThemeStatusBarView: View {
    @ObservedObject private var registry = LumiUIThemeRegistry.shared

    var body: some View {
        StatusBarHoverContainer(
            detailView: ThemePickerDetailView(),
            popoverWidth: 320,
            id: "lumi-theme-picker"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                    .font(.appMicroEmphasized)
                if let contribution = registry.selectedContribution {
                    Text(contribution.displayName)
                        .font(.appMicro)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}
