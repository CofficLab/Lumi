import SwiftUI
import LumiUI

/// 系列 Tab 按钮，横向排列
struct SeriesTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .appSurface(
                    style: .custom(isSelected ? Color(hex: "7C6FFF") : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))),
                    cornerRadius: 6
                )
                .foregroundColor(isSelected ? .white : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
