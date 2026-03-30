import SwiftUI

/// 设置侧边栏菜单项视图
struct SidebarItemView: View {
    let label: Label<Text, Image>
    let isSelected: Bool
    let action: () -> Void

    /// 原始初始化：接受 Label 参数（设置页使用）
    init(label: Label<Text, Image>, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    /// 便捷初始化：接受 title + icon 参数（左侧栏使用）
    init(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.label = Label(title, systemImage: icon)
        self.isSelected = isSelected
        self.action = action
    }

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
        .appSurface(
            style: .custom(isSelected ? Color.secondary.opacity(0.25) : Color.clear),
            cornerRadius: 6
        )
    }
}
