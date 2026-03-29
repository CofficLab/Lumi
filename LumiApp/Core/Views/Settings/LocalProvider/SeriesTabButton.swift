import SwiftUI

/// 系列 Tab 按钮，横向排列
struct SeriesTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppUI.Typography.caption1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .appSurface(
                    style: .custom(isSelected ? AppUI.Color.semantic.primary : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))),
                    cornerRadius: 6
                )
                .foregroundColor(isSelected ? .white : AppUI.Color.semantic.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("双击切换模型系列")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
