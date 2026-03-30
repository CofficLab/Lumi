import SwiftUI

/// 供应商选择按钮组件
struct ProviderButton: View {
    let provider: LLMProviderInfo
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(provider.displayName)
                    .font(AppUI.Typography.caption1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .appSurface(
                style: .custom(backgroundColor),
                cornerRadius: 6
            )
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(provider.displayName)
        .accessibilityHint("双击切换 LLM 供应商")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected { return AppUI.Color.semantic.primary }
        if isHovered { return Color.white.opacity(0.12) }
        return Color.white.opacity(0.05)
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        return AppUI.Color.semantic.textSecondary
    }
}
