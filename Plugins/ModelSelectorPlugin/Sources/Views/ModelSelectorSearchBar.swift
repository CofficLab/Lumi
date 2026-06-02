import SwiftUI
import LumiUI

/// 模型选择器搜索栏
/// 使用 LumiUI 的 AppSearchBar 组件
public struct ModelSelectorSearchBar: View {
    /// 搜索关键词
    @Binding var searchText: String

    /// 关闭回调
    public let onCancel: () -> Void

    public var body: some View {
        HStack(spacing: 8) {
            AppSearchBar(
                text: $searchText,
                placeholder: "Search Models"
            )

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
