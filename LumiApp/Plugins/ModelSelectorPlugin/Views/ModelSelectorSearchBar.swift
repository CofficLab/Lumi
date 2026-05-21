import SwiftUI
import LumiUI

/// 模型选择器搜索栏
/// 使用 LumiUI 的 AppSearchBar 组件
struct ModelSelectorSearchBar: View {
    /// 搜索关键词
    @Binding var searchText: String

    /// 关闭回调
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            AppSearchBar(
                text: $searchText,
                placeholder: String(localized: "Search Models", table: "AgentChat")
            )

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppUI.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
    }
}
