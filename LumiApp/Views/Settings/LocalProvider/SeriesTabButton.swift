import SwiftUI
import LumiUI

/// 系列 Tab 按钮，横向排列
struct SeriesTabButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .appSurface(
                    style: surfaceStyle,
                    cornerRadius: 6,
                    borderColor: borderColor,
                    lineWidth: 1
                )
                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("切换模型系列")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var surfaceStyle: AppSurfaceStyle {
        if isSelected {
            return .listRowSelected
        }
        if isHovered {
            return .listRowHover
        }
        return .listRow
    }

    private var borderColor: Color? {
        if isSelected {
            return theme.appSelectedBorder
        }
        if isHovered {
            return theme.appHoverBorder
        }
        return nil
    }
}
