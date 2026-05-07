import SwiftUI

/// 模型选择器搜索栏
struct ModelSelectorSearchBar: View {
    /// 搜索关键词
    @Binding var searchText: String

    /// 关闭回调
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            TextField(String(localized: "Search Models", table: "AgentChat"), text: $searchText)
                .textFieldStyle(.plain)

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
