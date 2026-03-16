import SwiftUI

/// 侧边栏菜单项视图
struct SidebarItemView: View {
    let label: Label<Text, Image>
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                label
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle()) // 告诉 Button：这一整块都是点击区域
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.secondary.opacity(0.25) : Color.clear)
        )
    }
}
